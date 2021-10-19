/*
 * read_data.h
 *
 *  Created on: 2020撟�9���25�
 *      Author: weiche
 */

#ifndef SRC_READ_DATA_H_
#define SRC_READ_DATA_H_

//data size define
#define ALL_SIZE 24649
#define COE_SIZE 24265
#define IFMAP_SIZE 384
#define M0EXPONENT_SIZE 5
#define OFMAP_SIZE	4

#define BIAS_SIZE_0 32
#define BIAS_SIZE_1	32
#define BIAS_SIZE_2	64
#define FC_BIAS_0 64
#define FC_BIAS_1 4

#define WEIGHTS_SIZE_0 480
#define WEIGHTS_SIZE_1 5120
#define WEIGHTS_SIZE_2 10240
#define FC_WEIGHTS_0 8192
#define FC_WEIGHTS_1 32

//store data
u64 *all;
u64 all0[ALL_SIZE];
u64 all_coe[COE_SIZE];

u64 *ifmap;
u64 ifmap0[IFMAP_SIZE];

u64 *m0exponent;
u64 m0exponent0[M0EXPONENT_SIZE];

u64 *bias;
u64 bias_0[BIAS_SIZE_0];
u64 bias_1[BIAS_SIZE_1];
u64 bias_2[BIAS_SIZE_2];
u64 fc_bias_0[FC_BIAS_0];
u64 fc_bias_1[FC_BIAS_1];

u64 *weights;
u64 weights_0[WEIGHTS_SIZE_0];
u64 weights_1[WEIGHTS_SIZE_1];
u64 weights_2[WEIGHTS_SIZE_2];
u64 fc_weights_0[FC_WEIGHTS_0];
u64 fc_weights_1[FC_WEIGHTS_1];

u64 *ofmap;
u64 data_out[OFMAP_SIZE];

int data_init();

#endif /* SRC_READ_DATA_H_ */
