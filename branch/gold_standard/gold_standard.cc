#include "include/types.h"
#include "include/bsv_predictor.hpp"
#include "ooo_cpu.h"

namespace {
  bsv_predictor bluespec_predictor;
}

void O3_CPU::initialize_branch_predictor() {
  bluespec_predictor.initialise();
}

uint8_t O3_CPU::predict_branch(uint64_t ip)
{
  uint8_t bsv_prediction = bluespec_predictor.predict_branch(ip);
  return bsv_prediction;
}


void O3_CPU::last_branch_result(uint64_t ip, uint64_t branch_target, uint8_t taken, uint8_t branch_type)
{    
    if(branch_type == BRANCH_CONDITIONAL){
      bluespec_predictor.last_branch_result(ip, branch_target, taken, branch_type);
    }
}
