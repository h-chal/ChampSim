#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdbool.h>
#include "types.h"


int pipe_read;
int pipe_write;
int update_read;

typedef struct {
  __uint64_t ip;
  __uint64_t target;
  __uint8_t taken;
  __uint8_t branch_type;
}  BranchUpdateInfo;

// Be aware of little endian encoding vs big endian
__uint64_t to_long(const unsigned char* charArray){
  __uint64_t result = 0;
  for(int i = 7; i >= 0; i--){
    result = (result << 8) | charArray[i];
  }
  return result;
}

void set_file_descriptors(){
  const char* fd_in = getenv(ENV_FIFO_IN);
  const char* fd_out = getenv(ENV_FIFO_OUT);
  pipe_read = atoi(fd_in);
  pipe_write = atoi(fd_out);
}


void branch_pred_req(unsigned int* res, unsigned char* buff){
  __uint64_t ip = to_long(buff);
  res[0] = res[0] | (ip << 2);
  res[1] = ip & 0x3FFFFFFFD0000000;
  res[2] = ip & 0xD000000000000000 >> 30;
}

void branch_update_req(unsigned int* res, unsigned char* buff){
  // Careful about padding
  int num = 0;
  
  BranchUpdateInfo ret;
  
  // Decode
  ret.ip = to_long(buff);
  ret.target = to_long(&buff[8]);
  ret.taken = buff[16] - '0';
  ret.branch_type = buff[17] - '0';      
  // For Bluespec
  res[0] = res[0] | (ret.ip & 0xFFFFFFFF) << 2; // 30
  res[1] = (ret.ip & 0x3FFFFFFFD0000000) >> 32;
  res[2] = ((ret.ip & 0xD000000000000000) >> 30) | ((ret.target & 0xFFFFFFFF) << 2);
  res[3] = (ret.target & 0x3FFFFFFFD0000000) >> 32;
  res[4] = ((ret.target & 0xD000000000000000) >> 30) | (ret.branch_type << 10) | (ret.taken << 2);
}

// 2 bits
void recieve(unsigned int* res){
  unsigned char buff[MSG_LENGTH];
  int num = 0;
  //printf("About to read from %d\n", pipe_read);
  // If requests aren't serviced then more requests aren't made.
  // E.g. forgetting to call branch_pred_resp :(
  num = read(pipe_read, buff, MSG_LENGTH);
  //printf("Done reading\n");
  if(num > 0){
    if(buff[0] == PREDICT_REQ){
      //printf("Recieving Pred\n");
      res[0] = PREDICT_REQ;  
      branch_pred_req(res, &buff[1]);
    }else if(buff[0] == UPDATE_REQ){
      //printf("Recieving Update\n");
      res[0] = UPDATE_REQ;
      branch_update_req(res, &buff[1]);
    }else{
      fprintf(stderr, "Recieving invalid data");
    }
  }else{
    perror("Error reading data\n");
  }
}

void setup_pred_resp(char taken, __uint64_t ip, char* buff){
  buff[0] = taken + '0';
  memcpy(&buff[1], &ip, 8);
}

void write_to_pipe(char* buff, int num_bytes){
  int num_written = write(pipe_write, buff, num_bytes);
  if(num_written != num_bytes){
    perror("Failed to write to pipe");
    exit(EXIT_FAILURE);
  }
}

void branch_pred_resp(char taken, __uint64_t ip){
  //printf("Waiting to write %ld\n", ip);
  char buff[PRED_RESP];
  setup_pred_resp(taken, ip, buff);
  write_to_pipe(buff, PRED_RESP);
  //printf("Done waiting\n");
}
