PRUNE=0
GPU=0
CUDNN=0
OPENCV=0
OPENMP=0
OPENBLAS=1
DEBUG=0
MULTI_CORE=0
AVX=1
QUANTIZATION=1

ARCH= -gencode arch=compute_30,code=sm_30 \
      -gencode arch=compute_35,code=sm_35 \
      -gencode arch=compute_50,code=[sm_50,compute_50] \
      -gencode arch=compute_52,code=[sm_52,compute_52]
#      -gencode arch=compute_20,code=[sm_20,sm_21] \ This one is deprecated?

# This is what I use, uncomment if you know your arch and want to specify
# ARCH= -gencode arch=compute_52,code=compute_52

VPATH=./src/:./examples
SLIB=libdarknet.so
ALIB=libdarknet.a
EXEC=darknet
OBJDIR=./obj/
MKLROOT=/workspace/ygao/software_backup/intel/mkl

# INCLUDEDIRS =  /I $(inc) /I $(mkl) /I $(LIBS)

CC=gcc
CPP=g++
NVCC=nvcc 
AR=ar
ARFLAGS=rcs
OPTS=-Ofast
LDFLAGS= -lm -pthread 
# COMMON= -Iinclude/ -Isrc/ -Idata/OpenBLAS/include
COMMON= -Iinclude/ -Isrc/ 
CFLAGS=-Wall -Wno-unused-result -Wno-unknown-pragmas -Wfatal-errors -fPIC


ifeq ($(DEBUG), 1) 
OPTS=-O0 -g
endif

CFLAGS+=$(OPTS)

ifeq ($(OPENCV), 1) 
COMMON+= -DOPENCV
CFLAGS+= -DOPENCV
LDFLAGS+= `pkg-config --libs opencv` -lstdc++
COMMON+= `pkg-config --cflags opencv` 
endif

ifeq ($(OPENBLAS), 1) 
COMMON+= -DMKL_ILP64
CFLAGS+= -DMKL_ILP64 -m64 -I${MKLROOT}/include
# LDFLAGS+= -L/data/OpenBLAS -lopenblas
# COMMON+= `pkg-config --cflags opencv` 
COMMON+= -I/workspace/ygao/software_backup/intel/mkl/include -I/workspace/ygao/software_backup/intel/include -I/workspace/ygao/software_backup/intel/compilers_and_libraries_2020.4.304/linux/mkl/include
LDFLAGS+= -L/workspace/ygao/software_backup/intel/mkl/lib/intel64 -L/workspace/ygao/software_backup/intel/mkl/lib/intel64_lin -L/workspace/ygao/software_backup/intel/lib/intel64 -L/workspace/ygao/software_backup/intel/lib/intel64_lin -lmkl_rt 
# LDFLAGS+= -Wl,--start-group ${MKLROOT}/lib/intel64/libmkl_intel_ilp64.a ${MKLROOT}/lib/intel64/libmkl_intel_thread.a ${MKLROOT}/lib/intel64/libmkl_core.a -Wl,--end-group -lpthread -lm -ldl
# LDFLAGS+= -Wl,--no-as-needed -lmkl_intel_ilp64 -lmkl_core -lgomp -lpthread -lm -ldl -lmkl_gnu_thread 
# COMMON+= `pkg-config --cflags opencv`
endif

ifeq ($(GPU), 1) 
COMMON+= -DGPU -I/usr/local/cuda/include/
CFLAGS+= -DGPU
LDFLAGS+= -L/usr/local/cuda/lib64 -lcuda -lcudart -lcublas -lcurand
endif

ifeq ($(CUDNN), 1) 
COMMON+= -DCUDNN 
CFLAGS+= -DCUDNN
LDFLAGS+= -lcudnn
endif

ifeq ($(AVX), 1) 
CFLAGS+= -ffp-contract=fast -msse3 -msse4.1 -msse4.2 -msse4a -mavx -mavx2 -mfma -DAVX
# CFLAGS+= -DAVX
endif

ifeq ($(PRUNE), 1) 
COMMON+= -DPRUNE
CFLAGS+= -DPRUNE
endif

ifeq ($(QUANTIZATION), 1) 
COMMON+= -DQUANTIZATION
CFLAGS+= -DQUANTIZATION
endif

ifeq ($(MULTI_CORE), 1) 
CFLAGS+= -fopenmp
LDFLAGS+= -lgomp
endif
OBJ=gemm.o utils.o cuda.o deconvolutional_layer.o convolutional_layer.o image.o activations.o im2col.o col2im.o blas.o crop_layer.o maxpool_layer.o softmax_layer.o data.o matrix.o network.o connected_layer.o parser.o option_list.o detection_layer.o route_layer.o upsample_layer.o box.o normalization_layer.o avgpool_layer.o layer.o local_layer.o shortcut_layer.o logistic_layer.o activation_layer.o batchnorm_layer.o region_layer.o reorg_layer.o tree.o  yolo_layer.o image_opencv.o list.o
EXECOBJA=segmenter.o detector.o darknet.o
ifeq ($(GPU), 1) 
LDFLAGS+= -lstdc++ 
OBJ+=convolutional_kernels.o deconvolutional_kernels.o activation_kernels.o im2col_kernels.o col2im_kernels.o blas_kernels.o crop_layer_kernels.o dropout_layer_kernels.o maxpool_layer_kernels.o avgpool_layer_kernels.o
endif

EXECOBJ = $(addprefix $(OBJDIR), $(EXECOBJA))
OBJS = $(addprefix $(OBJDIR), $(OBJ))
DEPS = $(wildcard src/*.h) Makefile include/darknet.h

all: obj backup results $(SLIB) $(ALIB) $(EXEC)
#all: obj  results $(SLIB) $(ALIB) $(EXEC)


$(EXEC): $(EXECOBJ) $(ALIB)
	$(CC) $(COMMON) $(CFLAGS) $^ -o $@ $(LDFLAGS) $(ALIB)

$(ALIB): $(OBJS)
	$(AR) $(ARFLAGS) $@ $^

$(SLIB): $(OBJS)
	$(CC) $(CFLAGS) -shared $^ -o $@ $(LDFLAGS) 

$(OBJDIR)%.o: %.cpp $(DEPS)
	$(CPP) $(COMMON) $(CFLAGS) -c $< -o $@

$(OBJDIR)%.o: %.c $(DEPS)
	$(CC) $(COMMON) $(CFLAGS) -c $< -o $@

$(OBJDIR)%.o: %.cu $(DEPS)
	$(NVCC) $(ARCH) $(COMMON) --compiler-options "$(CFLAGS)" -c $< -o $@

obj:
	mkdir -p obj
backup:
	mkdir -p backup
results:
	mkdir -p results

.PHONY: clean

clean:
	rm -rf $(OBJS) $(SLIB) $(ALIB) $(EXEC) $(EXECOBJ) $(OBJDIR)/*

