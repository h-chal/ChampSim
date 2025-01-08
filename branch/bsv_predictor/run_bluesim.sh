#!/usr/bin/env bluetcl
# search in PATH for bluetcl, then use that to interpret this script

package require Bluesim

Bluesim::sim load branch/bsv_predictor/Build/mkTestbench_bsim.so mkTestbench

Bluesim::sim run