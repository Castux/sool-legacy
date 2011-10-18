#include <stdint.h>

typedef uint8_t sool_bool;
typedef uint8_t sool_byte;
typedef uint32_t sool_int;
typedef double sool_num;
typedef void *sool_opaque;

#define SOOL_ARRAY_TEMPLATE(type) typedef struct {sool_int length; sool_##type data[];} *sool_array_##type;

SOOL_ARRAY_TEMPLATE(bool)
SOOL_ARRAY_TEMPLATE(byte)
SOOL_ARRAY_TEMPLATE(int)
SOOL_ARRAY_TEMPLATE(num)
SOOL_ARRAY_TEMPLATE(opaque)
