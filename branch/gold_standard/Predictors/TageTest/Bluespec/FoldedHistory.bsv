import GlobalBranchHistory::*;
import BranchParams::*;
import Vector::*;

`define MAX_SPEC_SIZE 8

// Assuming out of order updates, would actually be simpler with in order updates as I could keep a pointer
/*
Alternatively - why not simply recompute the global brnach history which will be easier since we will just shift and load
back in old values, then we can do a full recomputation of the folded history, however it may increase the cycle time

Also need to think about folding historu size, what if less than th

Periodically shift for recovery?

Multiple recovery updates to history? hopefully not possible but may need EHRs


*/

interface RecoverMechanism#(numeric type length);
    method ActionValue#(Bit#(length)) undo;
endinterface


interface FoldedHistory#(numeric type length);
    method Bit#(length) history;
    method Action updateHistory(GlobalBranchHistory#(GlobalHistoryLength) global, Bit#(1) newHistory);
    interface Vector#(`MAX_SPEC_SIZE, RecoverMechanism#(length)) recoverFrom;
endinterface


module mkFoldedHistory#(Integer histLength)(FoldedHistory#(length));
    Reg#(Bit#(length)) folded_history <- mkReg(0);
    
    // For out of order recovery of branch history
    Reg#(Bit#(`MAX_SPEC_SIZE)) last_spec_outcomes <- mkReg(0);
    Reg#(Bit#(`MAX_SPEC_SIZE)) last_removed_history <- mkReg(0);

    PulseWire recover <- mkPulseWire;
    PulseWire update <- mkPulseWire;
    RWire#(Tuple2#(Bit#(GlobalHistoryLength), Bit#(1))) historyUpdateData <- mkRWire;

    Vector#(`MAX_SPEC_SIZE, RecoverMechanism#(length)) recoverIfc;

    rule updateHist(!recover && update);
        if(historyUpdateData.wget matches tagged Valid {.global, .newHistory}) begin
        
        Bit#(1) new_bit = newHistory ^ folded_history[valueOf(length)-1];
        Bit#(length) new_folded_history = truncateLSB({folded_history, new_bit} << 1);

        // Eliminate history out of bounds
        Integer i = histLength % valueOf(length);
        Bit#(1) eliminateBit = global[histLength-1];
        new_folded_history[i] = new_folded_history[i] ^ eliminateBit;
        
        folded_history <= new_folded_history;

        // For recovery updates
        last_spec_outcomes <= truncateLSB({last_spec_outcomes, newHistory} << 1);
        last_removed_history <= truncateLSB({last_removed_history, eliminateBit} << 1);
        end
    endrule

    for(Integer i = 0; i < `MAX_SPEC_SIZE; i = i+1) begin
        recoverIfc[i] = (interface RecoverMechanism#(length);
            method ActionValue#(Bit#(length)) undo;
                //recover.send;
                
                Bit#(length) recovered = folded_history;
                Integer j = histLength % valueOf(length);
                for(Integer k = 0; k < i+1; k = k +1) begin                    
                    Bit#(1) eliminateBit = last_removed_history[k];
                    Integer position = (j + k) % valueOf(length);
                    recovered[position] = eliminateBit^recovered[position];
                
                end
                
                Bit#(length) removed = recovered[i:0] ^ last_spec_outcomes[i:0];
                //(folded_history >> pointer) | (removed[pointer:0] << )
                recovered =  removed[i:0] << (valueOf(length)-i-1) | truncateLSB(recovered >> (i+1));

                
                

                $display("Spec %b\n", last_spec_outcomes);
                $display("Removed history %b\n", last_removed_history);
                $display("Recovered %b\n", recovered);
                return recovered;
            endmethod
        endinterface);
    end

    interface recoverFrom = recoverIfc;

    method Bit#(length) history = folded_history;




    // How to know the pointer? Realistically commit stage cannot know
    // If in order then fetch stage will know which branch because we can keep a pointer
    // But that also requires sending back correct updates to the global history

    
    

    method Action updateHistory(GlobalBranchHistory#(GlobalHistoryLength) global, Bit#(1) newHistory);
        // Shift and add new history bit, with older history
        update.send;
        historyUpdateData.wset(tuple2(global.history, newHistory));
    endmethod

endmodule
//if(lat[j].wget matches tagged Valid .x)