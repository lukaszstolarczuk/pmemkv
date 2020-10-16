// SPDX-License-Identifier: BSD-3-Clause
/* Copyright 2020, Intel Corporation */

#include "../all/put_get_std_map.hpp"

const size_t key_length = 10;
const size_t value_length = 10;

static void reserve_and_insert(std::string engine, std::string config, size_t reserve,
			       size_t insert)
{
	auto cfg = CONFIG_FROM_JSON(config);
	cfg.reserve(reserve);

	auto kv = INITIALIZE_KV(engine, std::move(cfg));

	auto proto = PutToMapTest(insert, key_length, value_length, kv);
	VerifyKv(proto, kv);

	CLEAR_KV(kv);
	kv.close();
}

static void test(int argc, char *argv[])
{
	if (argc < 5)
		UT_FATAL("usage: %s engine json_config reserve insert", argv[0]);

	size_t reserves = std::stoull(argv[3]);
	size_t inserts = std::stoull(argv[4]);

	/* reserve nothing, then insert */
	reserve_and_insert(argv[1], argv[2], reserves, inserts);
}

int main(int argc, char *argv[])
{
	return run_test([&] { test(argc, argv); });
}
