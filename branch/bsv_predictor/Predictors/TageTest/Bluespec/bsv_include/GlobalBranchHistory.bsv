// Simple global history
// No speculative recovery or anything
import BranchParams::*;
import Vector::*;
import ConfigReg::*;

interface RecoverMechanism#(numeric type length);
    method ActionValue#(Bit#(length)) undo;
endinterface

interface GlobalBranchHistory#(numeric type length);
    method Bit#(length) history;
    method Action addHistory(Bit#(1) taken);
    interface Vector#(MaxSpecSize, RecoverMechanism#(length)) recoverFrom;
endinterface

module mkGlobalBranchHistory(GlobalBranchHistory#(length));
    Reg#(Bit#(length)) shift_register <- mkConfigReg(0);
    Reg#(Bit#(MaxSpecSize)) last_removed_history <- mkReg(0);
    
    PulseWire recover <- mkPulseWire;
    PulseWire update <- mkPulseWire;
    RWire#(Bit#(1)) updateHistoryData <- mkRWire;

    Vector#(MaxSpecSize, RecoverMechanism#(length)) recoverIfc;

    (* no_implicit_conditions, fire_when_enabled *)
    rule updateHistory(update && !recover);
        if(updateHistoryData.wget matches tagged Valid .taken) begin
            shift_register <= truncateLSB({shift_register, taken} << 1);
            
            last_removed_history <= truncateLSB({last_removed_history, shift_register[valueOf(length)-1]} << 1);
        end
    endrule

    for(Integer i = 0; i < valueOf(MaxSpecSize); i = i+1) begin
        recoverIfc[i] = (interface RecoverMechanism#(length);
            method ActionValue#(Bit#(length)) undo;
                recover.send;
                Bit#(length) recovered = last_removed_history[i:0] << (valueOf(length)-i-1) | truncateLSB(shift_register >> (i+1));
                shift_register <= recovered;
                return recovered;
            endmethod
        endinterface);
    end
    interface recoverFrom = recoverIfc;

    method Action addHistory(Bit#(1) taken);
        updateHistoryData.wset(taken);
        update.send;
    endmethod

    method history = shift_register;
endmodule