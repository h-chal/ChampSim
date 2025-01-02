import GlobalBranchHistory::*;
import FoldedHistory::*;
import BranchParams::*;
import LFSR::*;
import TaggedTable::*;
import Assert::*;

typedef 10 FoldingSize;


(* synthesize *)
module mkTableTestBench(Empty);
   
    LFSR#(Bit#(16)) lfsr <- mkLFSR_16;

    Reg#(Bool) starting <- mkReg(True);
    Reg#(UInt#(10)) count <- mkReg(0);

    GlobalBranchHistory#(GlobalHistoryLength) gb <- mkGlobalBranchHistory;
    TaggedTable#(5, 5, 10) tg <- mkTaggedTable;
 

    rule start(starting);
        lfsr.seed(9);
        starting <= False;
    endrule

    //(* conflict_free = "gb_updateHistory, run" *)
    rule run (!starting);
        //x <= ~x;
        Bit#(1) value = lfsr.value[0];
        lfsr.next;
        
        TaggedTableEntry#(5) t = tg.access_entry(13);

        gb.addHistory(value);
        tg.updateHistory(gb, value);
        

        $display("tag: %d\n", t.predictionCounter);

        if(count == 55) begin
            $finish(0);
        end

        if(count % 5 == 0) begin
            let r <- tg.recoverHistory(0);
            $display("Recovered %b\n", r);
        end
        count <= count +1;


        
    endrule
endmodule