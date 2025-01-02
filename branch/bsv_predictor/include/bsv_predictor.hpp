#ifndef BSV_PREDICTOR_HPP
#define BSV_PREDICTOR_HPP

#include <optional>
#include <utility>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <poll.h>
#include <functional>
#include <cassert>
#include <cstring>
#include <queue>
#include "types.h"


#include "ooo_cpu.h"
#include "tracereader.h"

#define RESP_SIZE PRED_RESP

#ifndef SCRIPT_LOCATION
#define SCRIPT_LOCATION "./branch/bsv_predictor/script.sh"
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

class bsv_predictor final : public predictor_concept{
    private:
      int req_pipe[2];
      int resp_pipe[2];
      std::optional<std::pair<uint64_t, uint8_t>> last_prediction;
      struct pollfd to_poll;
      
      // Debug
      u_int64_t count;
      uint64_t total_prefetched;
      uint64_t last_received;

      void initiate_bsim();
      uint8_t read_prediction_response(uint64_t ip);

    public:
      bsv_predictor() : last_prediction{}, count(0), total_prefetched(0) {}
      void initialise();
      void last_branch_result(uint64_t ip, uint64_t target, uint8_t taken, uint8_t branch_type);
      virtual uint8_t predict_branch(uint64_t ip);
      
      ~bsv_predictor() noexcept {}
};

void write_prediction(uint64_t branch_ip, int fd, uint64_t& total_prefetched){
  std::array<char, MSG_LENGTH> buff;

  debug_printf("Prediction Request %ld\n", branch_ip);
  
  buff[0] = PREDICT_REQ;
  memcpy(std::data(buff)+1, &branch_ip, sizeof(branch_ip));
  if(write(fd, std::data(buff), MSG_LENGTH) == -1){
    perror("Requesting prediction");
  }
  total_prefetched++;
}

void write_update(uint64_t ip, uint64_t branch_target, uint8_t taken, uint8_t branch_type, int fd){
    std::array<char, MSG_LENGTH> buff;

    buff[0] = UPDATE_REQ;
    memcpy(std::data(buff)+1, &ip, sizeof(ip));
    memcpy(std::data(buff)+1+sizeof(ip), &branch_target, sizeof(branch_target));
    buff[1+sizeof(ip)+sizeof(branch_target)] = taken + '0';
    buff[2+sizeof(ip)+sizeof(branch_target)] = branch_type + '0';

    if(write(fd, std::data(buff), MSG_LENGTH) == -1){
      perror("Requesting update");
    }
}

uint8_t bsv_predictor::read_prediction_response(uint64_t ip){
  std::array<char, RESP_SIZE> buff;
  uint8_t out = 0;
  uint64_t received_ip;
  
  if(read(resp_pipe[0], std::data(buff), RESP_SIZE) > 0){
        memcpy(&received_ip, std::data(buff)+1, 8);

        if(received_ip == ip){
          out = buff[0] - '0';
          count++; last_received = ip;
          debug_printf("Prediction Done %ld\n", received_ip);
        }
        else{
          last_prediction = {received_ip, buff[0]-'0'};
        }
  }else{
      perror("Receiving prediction");
  }
  return out;
}

uint8_t bsv_predictor::predict_branch(uint64_t ip){
   uint8_t out = 0;
   debug_printf("Predict %ld\n", ip);
   
   if(last_prediction){
    if((*last_prediction).first == ip){
      out = (*last_prediction).second;
      debug_printf("Prediction Received %ld, %d\n", ip, out);
      last_prediction.reset();
      count++; last_received = ip;
    }
   }else{
    debug_printf("total prefetch: %ld, since prefetch: %ld\n", total_prefetched, count);
    if (poll(&to_poll, 1, 0)==1 || total_prefetched > count) {
        out = read_prediction_response(ip);
    }else{
      debug_printf("Skipped %ld\n", ip);
    }
  }
  return out;
}

void bsv_predictor::last_branch_result(uint64_t ip, uint64_t branch_target, uint8_t taken, uint8_t branch_type){
  if(branch_type == BRANCH_CONDITIONAL){
      debug_printf("Update %ld, branch target: %ld, taken: %d, branch type: %d, count: %ld, last_received: %ld \n", ip, branch_target, taken, branch_type, count, last_received);
      assert(last_received == ip);
   }
    //write_update(ip, branch_target, taken, branch_type);
  return;
}

void bsv_predictor::initialise(){
  initiate_bsim();
  to_poll.events = POLLIN;
  to_poll.fd = resp_pipe[0];

  std::function<void(uint64_t, uint64_t, uint8_t, uint8_t)> send = [this](uint64_t branch_ip, uint64_t branch_target, uint8_t branch_taken, uint8_t branch_type){
    write_prediction(branch_ip, req_pipe[1], total_prefetched);
    write_update(branch_ip, branch_target, branch_taken, branch_type, req_pipe[1]);
  };
  
  champsim::enable_ahead_predictions(req_pipe[1], send, &total_prefetched);
}

void bsv_predictor::initiate_bsim(){
  pid_t pid;
  if(pipe(req_pipe) < 0) exit(1);
  if(pipe(resp_pipe) < 0) exit(1);

  pid = fork();
  if(pid == -1){
    perror("Fork");
    exit(EXIT_FAILURE);
  }

  if(pid == 0){
    char run[] = SCRIPT_LOCATION;
    char* args[] = {run, NULL};
    char pred_in_arg[20], pred_out_arg[20];

    
    sprintf(pred_in_arg, "%s=%d", ENV_FIFO_IN, req_pipe[0]);
    sprintf(pred_out_arg, "%s=%d", ENV_FIFO_OUT, resp_pipe[1]);
    char* env[] = {pred_in_arg, pred_out_arg, NULL};

    execve(run, args, env);
    perror("Error running script");
    fprintf(stderr, "Script: %s\n", run);
    fprintf(stderr, "Args: %s\n", *args);
    fprintf(stderr, "Error code: %d (%s)\n", errno, strerror(errno));
    exit(EXIT_FAILURE);
  }
}
#endif