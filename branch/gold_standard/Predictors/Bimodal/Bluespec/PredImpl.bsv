import BrPred::*;
import RegFile::*;
import Vector::*;


typedef 12 PCIndexSz;
typedef Bit#(PCIndexSz) PCIndex;
typedef Bit#(2) Entry;

typedef struct {
    Entry counter;
    PCIndex pc;
} BimodalTrainInfo deriving(Bits, Eq, FShow);

typedef BimodalTrainInfo DirPredTrainInfo;

module mkPredImpl(DirPredictor#(BimodalTrainInfo));
    RegFile#(PCIndex, Entry) bimodal_table <- mkRegFileWCF(0, maxBound);
    Reg#(Addr) currentPc <- mkReg(?);

    Vector#(SupSize, DirPred#(BimodalTrainInfo)) predIfc;
    Reg#(Bit#(1)) dummy <- mkReg(0);

    for(Integer i=0; i < valueOf(SupSize); i=i+1) begin
        predIfc[i] = (interface DirPred;
            method ActionValue#(DirPredResult#(BimodalTrainInfo)) pred;
                PCIndex index = truncate(offsetPc(currentPc,i) >> 2);
                Entry entry = bimodal_table.sub(index);
                //$display("pc: %d bsv index: %d counter: %d\n", currentPc, index, entry);

                return DirPredResult {
                    taken: unpack(truncateLSB(entry)),
                    train: BimodalTrainInfo {
                        counter: entry,
                        pc: index
                    }
                };
            endmethod
        endinterface);
    end

    interface pred = predIfc;

    method Action update(Bool taken, BimodalTrainInfo train, Bool mispred);
        Entry newEntry = train.counter;
        if(taken) begin
            newEntry = (newEntry == maxBound ? maxBound : newEntry + 1);
           end
        else begin
            newEntry = (newEntry == 0 ? 0 : newEntry - 1);
        end
        bimodal_table.upd(train.pc, newEntry);
    endmethod

    method Action nextPc(Addr pc);
        currentPc <= pc;
    endmethod

    method flush = noAction;
    method flush_done = True;
endmodule