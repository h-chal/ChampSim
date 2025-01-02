import GlobalBranchHistory::*;
import FoldedHistory::*;
import BrPred::*;
import BranchParams::*;
import RegFile::*;

/*
typedef struct {
    Entry counter;
    Addr pc;
} TageTrainInfo deriving(Bits, Eq, FShow);
*/

typedef 3 PredCtrSz;
typedef Bit#(PredCtrSz) PredCtr;

typedef 2 UsefulCtrSz;
typedef Bit#(UsefulCtrSz) UsefulCtr;

typedef struct {
    PredCtr predictionCounter;
    UsefulCtr usefulCounter;
    Bit#(tagSize) tag;
} TaggedTableEntry#(numeric type tagSize) deriving(Bits, Eq, FShow);


interface TaggedTable#(numeric type tagSize, numeric type indexSize, numeric type historyLength);
    method TaggedTableEntry#(tagSize) access_entry(Addr pc);
    method Tuple2#(Bit#(tagSize), Bit#(indexSize)) trainingInfo(Addr pc); // To be used in training

    method Action updateHistory(GlobalBranchHistory#(GlobalHistoryLength) global, Bit#(1) taken);
    method ActionValue#(Bit#(TAdd#(tagSize, indexSize))) recoverHistory(Bit#(MaxSpecSize) numRecovery);

    //method Action update_entry(Bit#(indexSize) index, TaggedTableEntry newEntry); // For now drag along whole entry, can't be recomputed unless mispredict
    //method Action allocate(Bit#(indexSize), Bit#(tagSize), Bool taken) // TODO Better to use a EHR/CReg for the folding history probably than to drag the index
endinterface

module mkTaggedTable(TaggedTable#(tagSize, indexSize, historyLength)) provisos(
    Add#(a__, indexSize, 64), 
    Add#(indexSize, tagSize, foldedSize));
    FoldedHistory#(TAdd#(tagSize, indexSize)) folded <- mkFoldedHistory(valueOf(historyLength));
    RegFile#(Bit#(indexSize), TaggedTableEntry#(tagSize)) tab <- mkRegFileWCF(0, maxBound);

    rule debug;
        $display("Folded: %b\n", folded.history);
    endrule

    method Action updateHistory(GlobalBranchHistory#(GlobalHistoryLength) global, Bit#(1) taken) = folded.updateHistory(global, taken);
    method ActionValue#(Bit#(foldedSize)) recoverHistory(Bit#(MaxSpecSize) numRecovery) = folded.recoverFrom[numRecovery].undo;

    method TaggedTableEntry#(tagSize) access_entry(Addr pc);
        Bit#(indexSize) index = folded.history[valueOf(indexSize)-1:0] ^ truncate(pc << 2); // TODO
        return tab.sub(index);
    endmethod


    //method Tuple2#(Bit#(tagSize), Bit#(indexSize)) trainingInfo(Addr pc);

    //endmethod

endmodule