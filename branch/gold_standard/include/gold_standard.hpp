#include<stdio.h>
#include<instruction.h>
#include<bitset>

#ifndef GOLDSTANDARD_HPP
#define GOLDSTANDARD_HPP

#ifndef SCRIPT_LOCATION
#define SCRIPT_LOCATION "./branch/gold_standard/script.sh"
#endif

#ifndef DEBUG_PRINTS
#define DEBUG_PRINTS 1
#endif

#define debug_printf(fmt, ...) \
  do { if(DEBUG_PRINTS) { \
    printf(fmt, __VA_ARGS__); \
    }}\
  while(0);

#define assert_message(expr, fmt, ...) \
  if(!(expr)) {\
    printf(fmt, __VA_ARGS__); \
    assert(expr); \
  }


class predictor_concept {
  public:  
      virtual ~predictor_concept() = default;
      virtual void initialise() = 0;
      virtual void last_branch_result(uint64_t ip, uint64_t target, uint8_t taken, uint8_t branch_type) = 0;
      virtual uint8_t predict_branch(uint64_t ip) = 0; 
};

namespace gold_standard {
  class gold_standard_predictor : predictor_concept {
  private:
    void impl_initialise();
    void impl_last_branch_result(uint64_t ip, uint64_t target, uint8_t taken, uint8_t branch_type);
    uint8_t impl_predict_branch(uint64_t ip); 

  public:
    void initialise(){
      impl_initialise();
    }
    void last_branch_result(uint64_t ip, uint64_t target, uint8_t taken, uint8_t branch_type){
      if(branch_type == BRANCH_CONDITIONAL){
        impl_last_branch_result(ip, target, taken, branch_type);
      }
    }
    uint8_t predict_branch(uint64_t ip){
      return impl_predict_branch(ip);
    }
  };
}

#endif
