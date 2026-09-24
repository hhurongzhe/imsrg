CC = g++
CXX = g++

SRC_DIR   := src
BUILD_DIR := build
OBJ_DIR   := $(BUILD_DIR)/obj
EXTERN := $(SRC_DIR)/extern
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S), Darwin)
OPT_PREFIX ?= /Users/mac/Desktop/opt_setup/opt
else
OPT_PREFIX ?=
endif
BOOST_PREFIX ?= $(if $(OPT_PREFIX),$(OPT_PREFIX)/boost)
GSL_PREFIX ?= $(if $(OPT_PREFIX),$(OPT_PREFIX)/gsl)
OPENBLAS_PREFIX ?= $(if $(OPT_PREFIX),$(OPT_PREFIX)/openblas)

LOCAL_PREFIXES := $(BOOST_PREFIX) $(GSL_PREFIX) $(OPENBLAS_PREFIX)
LOCAL_INCLUDE_DIRS := $(addsuffix /include,$(LOCAL_PREFIXES))
LOCAL_LIB_DIRS := $(addsuffix /lib,$(LOCAL_PREFIXES))
comma := ,

SOURCE_DIRS := $(SRC_DIR) $(addprefix $(SRC_DIR)/,Commutator ReferenceImplementations ThreeBodyME imsrg_util)
INCLUDE   = $(addprefix -I,$(SOURCE_DIRS)) -I$(EXTERN)/armadillo -I$(EXTERN)/half/include $(addprefix -I,$(LOCAL_INCLUDE_DIRS))
FLAGS     = -fPIC -O3 -fopenmp -march=native -std=c++17 -DNO_HDF5
DEPFLAGS  = -MMD -MP
LDFLAGS   = $(addprefix -L,$(LOCAL_LIB_DIRS)) $(foreach dir,$(LOCAL_LIB_DIRS),-Wl$(comma)-rpath$(comma)$(dir))
LIBS      = -lboost_iostreams -lgsl -lgslcblas -lopenblas -lm -lz
SOFLAGS   = -shared $(FLAGS)
LIB_SOFLAGS = $(SOFLAGS)
EXE_RPATH = -Wl,-rpath,'$$ORIGIN'
PYTHON_CONFIG ?= python3-config
PYTHON ?= python3
PYTHON_INCLUDE = -I$(EXTERN)/pybind11/include
PYTHON_CFLAGS = $(filter-out -arch arm64 x86_64,$(shell $(PYTHON_CONFIG) --cflags))
PYTHON_LDFLAGS = $(shell $(PYTHON_CONFIG) --ldflags)
STUBGEN_FLAGS = --ignore-invalid-expressions '.*'

ALL = $(BUILD_DIR)/libIMSRG.so $(BUILD_DIR)/imsrg++ $(BUILD_DIR)/pyIMSRG.so

# --- 操作系统检测与路径设置 ---
ifeq ($(UNAME_S), Darwin) # macOS 系统
	CC = g++-16
	CXX = g++-16
	FLAGS += -DNO_x86
	# GCC's built-in SDK path may be stale after a Command Line Tools update.
	MACOS_SDK := $(shell xcrun --sdk macosx --show-sdk-path)
	FLAGS += -isysroot "$(MACOS_SDK)"
	PYTHON_LDFLAGS += -undefined dynamic_lookup
	LIB_SOFLAGS = -dynamiclib $(FLAGS) -Wl,-install_name,@rpath/libIMSRG.so
	EXE_RPATH = -Wl,-rpath,@loader_path
	ALL += $(BUILD_DIR)/pyIMSRG/__init__.pyi
endif

.PHONY: all clean python stubs FORCE

all: $(ALL)
python: $(BUILD_DIR)/pyIMSRG.so
ifeq ($(UNAME_S), Darwin)
stubs: $(BUILD_DIR)/pyIMSRG/__init__.pyi
else
stubs:
	@echo "pyIMSRG stubs are only generated on macOS."
endif

OBJ_NAMES = ModelSpace.o TwoBodyME.o Operator.o ReadWrite.o \
      HartreeFock.o Generator.o GeneratorPV.o IMSRGSolver.o IMSRGSolverPV.o \
      BCH.o AngMom.o AngMomCache.o \
      IMSRGProfiler.o \
      Commutator/Commutator.o Commutator/TensorCommutators.o Commutator/IMSRG3Commutators.o \
      Commutator/FactorizedDoubleCommutator.o Commutator/DaggerCommutators.o \
      HFMBPT.o RPA.o \
      imsrg_util/imsrg_util.o imsrg_util/M0nu.o imsrg_util/Pwd.o \
      imsrg_util/DarkMatterNREFT.o imsrg_util/Atomic.o Jacobi3BME.o UnitTest.o \
      TwoBodyChannel.o ThreeBodyChannel.o \
      ThreeBodyME/ThreeBodyME.o ThreeBodyME/ThreeBodyStorage.o \
      ThreeBodyME/ThreeBodyStorage_pn.o ThreeBodyME/ThreeBodyStorage_iso.o \
      ThreeBodyME/ThreeBodyStorage_no2b.o ThreeBodyME/ThreeBodyStorage_mono.o ThreeLegME.o \
      version.o \
      ReferenceImplementations/ReferenceImplementations.o ReferenceImplementations/HFMBPT4.o \
      ReferenceImplementations/IMSRG2Commutators.o ReferenceImplementations/IMSRG3Commutators.o \
      ReferenceImplementations/IMSRG2TensorCommutators.o ReferenceImplementations/IMSRG3TensorCommutators.o \
      ReferenceImplementations/FactorizedNestedCommutators.o

OBJ = $(addprefix $(OBJ_DIR)/,$(OBJ_NAMES))
MAIN_OBJ = $(OBJ_DIR)/imsrg++.o
PYIMSRG_OBJ = $(OBJ_DIR)/pyIMSRG.o
DEP = $(OBJ:.o=.d) $(MAIN_OBJ:.o=.d) $(PYIMSRG_OBJ:.o=.d)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cc Makefile | $(OBJ_DIR)
	@mkdir -p $(@D)
	$(CXX) -c $< -o $@ $(INCLUDE) $(FLAGS) $(DEPFLAGS)

$(PYIMSRG_OBJ): $(SRC_DIR)/pyIMSRG.cc Makefile | $(OBJ_DIR)
	$(CXX) -c $< -o $@ $(INCLUDE) $(PYTHON_INCLUDE) $(FLAGS) $(PYTHON_CFLAGS) $(DEPFLAGS)

$(BUILD_DIR)/libIMSRG.so: $(OBJ) | $(BUILD_DIR)
	$(CXX) $^ $(LIB_SOFLAGS) -o $@ $(LDFLAGS) $(LIBS)

$(BUILD_DIR)/imsrg++: $(MAIN_OBJ) $(BUILD_DIR)/libIMSRG.so | $(BUILD_DIR)
	$(CXX) $< -o $@ $(FLAGS) -L$(BUILD_DIR) -lIMSRG $(EXE_RPATH) $(LDFLAGS) $(LIBS)

$(BUILD_DIR)/pyIMSRG.so: $(OBJ) $(PYIMSRG_OBJ) | $(BUILD_DIR)
	$(CXX) $^ $(SOFLAGS) -o $@ $(LDFLAGS) $(PYTHON_LDFLAGS) $(LIBS)

$(BUILD_DIR)/pyIMSRG/__init__.pyi: $(BUILD_DIR)/pyIMSRG.so | $(BUILD_DIR)
	cd $(BUILD_DIR) && $(PYTHON) -m pybind11_stubgen pyIMSRG -o . $(STUBGEN_FLAGS)

# Refresh Git metadata without recompiling when the version is unchanged.
FORCE:

$(BUILD_DIR)/version.cc: FORCE | $(BUILD_DIR)
	@branch=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown); \
	rev=$$(git rev-parse --short HEAD 2>/dev/null || echo unknown); \
	dirty=$$(git diff HEAD --quiet 2>/dev/null || printf '+'); \
	printf '#include "version.hh"\nnamespace version {\nstd::string BuildVersion() { return "%s_%s%s"; }\n}\n' \
	  "$$branch" "$$rev" "$$dirty" > $@.tmp; \
	if cmp -s $@.tmp $@; then rm -f $@.tmp; else mv $@.tmp $@; fi

$(OBJ_DIR)/version.o: $(BUILD_DIR)/version.cc Makefile | $(OBJ_DIR)
	$(CXX) -c $< -o $@ $(INCLUDE) $(FLAGS) $(DEPFLAGS)

$(BUILD_DIR) $(OBJ_DIR):
	mkdir -p $@

clean:
	rm -rf $(BUILD_DIR)

-include $(DEP)
