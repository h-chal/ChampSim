import StmtFSM::*;
import BrPred::*;
import Predictor::*;

import "BDPI" function Action branch_pred_resp(Bit#(8) taken, Address ip);
import "BDPI" function ActionValue#(Bit#(160)) receive();
import "BDPI" function Action set_file_descriptors;

typedef UInt#(64) Address;

typedef struct {
    UInt#(64) ip;
    UInt#(64) target;
    UInt#(8) taken;
    UInt#(8) branch_type;
} BranchUpdateInfo deriving(Bits, Eq, FShow);

typedef union tagged{
  BranchUpdateInfo UpdateReq;
  Address PredictReq;
} Message deriving(Bits, Eq, FShow);

(* synthesize *)
module mkTestbench(Empty);
    

    Reg#(Bit#(8)) prediction <- mkReg(0);
    Reg#(Message) message <- mkReg(?);
    let predictor <- mkDirPredictor;
    
    Reg#(DirPredResult#(DirPredTrainInfo)) pendingTrainInfo <- mkReg(DirPredResult{taken: False, train: ?});
    
    function Action predict(Address ip);
      action let a <- predictor.pred[0].pred; pendingTrainInfo <= a; endaction
    endfunction

    function Action update(BranchUpdateInfo updateInfo);
      // Forces in order updates pretty much
      let branch_taken = updateInfo.taken == 1;
      return predictor.update(branch_taken, pendingTrainInfo.train, branch_taken != pendingTrainInfo.taken);
    endfunction

    function BranchUpdateInfo convertUpdate(Bit#(160) b);
      UInt#(64) ip = unpack(b[65:2]);
      UInt#(64) target = unpack(b[129:66]);
      UInt#(8) taken = unpack(b[137:130]);
      UInt#(8) branch_type = unpack(b[145:138]);
      return BranchUpdateInfo{ip: ip, target: target, taken: taken, branch_type: branch_type};
    endfunction

    function Message convertToMessage(Bit#(160) m);
      UInt#(2) t = unpack(m[1:0]);
      Message ret;
      if (t == fromInteger(1)) begin 
        ret = PredictReq(unpack(m[65:2]));
      end
      else  begin
        ret = UpdateReq(convertUpdate(m));
      end
      return ret;
    endfunction

    function Bool isPred(Message m);
      Bool x = False;
      case(m) matches
        tagged PredictReq .pr : x = True;
      endcase
      return x;
    endfunction


    Stmt stmt = seq 
      set_file_descriptors;
        while(True) seq
          action let a <- receive; message <= convertToMessage(a); endaction
          if (isPred(message)) seq
            //$display("bsv predict %d", message.PredictReq);
            predictor.nextPc(pack(message.PredictReq));
            predict(message.PredictReq);
            branch_pred_resp({7'b0000000,pack(pendingTrainInfo.taken)}, message.PredictReq);
          endseq
          if (!isPred(message)) seq
            //$display("bsv update %d", message.UpdateReq.ip);
            update(message.UpdateReq);
          endseq
        endseq
    endseq;

    

  mkAutoFSM(stmt);
endmodule
