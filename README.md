# h-chal's fork of ChampSim

This is a fork of a fork of [ChampSim](https://github.com/ChampSim/ChampSim).

[KatyT12](https://github.com/KatyT12/ChampSim) forked ChampSim to allow branch predictors to be written in Bluespec SystemVerilog.

I have forked that work to make it work on my machine. In the future I may copy her approach to allow other ChampSim functionality to be modelled with BSV, e.g. prefetching.

All of my branches start with `h-chal/`.

The README for ChampSim can be found [here](README_champsim.md).

# Instructions
- Install bsc (which I believe includes bluesim)
- Use vcpkg
```
git submodule update --init
vcpkg/bootstrap-vcpkg.sh
vcpkg/vcpkg install
```
- Download a trace e.g. `wget -P ~/diss/traces/DPC-3 https://dpc3.compas.cs.stonybrook.edu/champsim-traces/speccpu/600.perlbench_s-210B.champsimtrace.xz`
- `./config.sh bsv_config.json` (selects predictor)
- `make`
- `bin/champsim --warmup-instructions 2000000 --simulation-instructions 5000000 ~/diss/traces/DPC-3/600.perlbench_s-210B.champsimtrace.xz`

Alternatively, you can modify and use `./try_bsv_predictor.sh`.
