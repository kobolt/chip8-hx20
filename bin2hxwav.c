#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <limits.h>

#define BITSTREAM_MAX 0x80000
#define DATA_MAX 0x4000
#define CHUNK_SIZE 0x40
#define DATA_BLOCK_SIZE 256
#define INFO_BLOCK_SIZE 80

#define SAMPLE_RATE 44100
#define SAMPLE_LEN 12



static uint8_t bitstream[BITSTREAM_MAX];
static int bitstream_n = 0;
static uint8_t data[DATA_MAX];
static uint8_t info[INFO_BLOCK_SIZE];
static uint16_t crc16 = 0;



static void crc16_update(uint8_t byte)
{
  int i;
  crc16 ^= byte;
  for(i = 0; i < 8; i++) {
    if (crc16 & 0x0001) {
      crc16 >>= 1;
      crc16 ^= 0x8408; /* Reverse 0x1021 */
    } else {
      crc16 >>= 1;
    }
  }
}



static void wav_generate(FILE *fh)
{
  int i;
  int j;
  uint32_t sample_count;
  uint32_t chunk_size;
  uint32_t sample_rate;
  uint32_t subchunk2_size;

  sample_count = 0;
  for (i = 0; i < bitstream_n; i++) {
    if (bitstream[i] == '0') {
      sample_count += (SAMPLE_LEN * 2);
    } else if (bitstream[i] == '1') {
      sample_count += (SAMPLE_LEN * 4);
    }
  }

  subchunk2_size = sample_count;
  chunk_size = subchunk2_size + 36;
  sample_rate = SAMPLE_RATE;

  /* Header: */
  fwrite("RIFF", sizeof(char), 4, fh);
  fwrite(&chunk_size, sizeof(uint32_t), 1, fh);
  fwrite("WAVE", sizeof(char), 4, fh);
  fwrite("fmt ", sizeof(char), 4, fh);
  fwrite("\x10\x00\x00\x00", sizeof(char), 4, fh); /* Subchunk1Size = 16 */
  fwrite("\x01\x00", sizeof(char), 2, fh); /* AudioFormat = 1 = PCM */
  fwrite("\x01\x00", sizeof(char), 2, fh); /* Channels = 1 = Mono */
  fwrite(&sample_rate, sizeof(uint32_t), 1, fh);
  fwrite(&sample_rate, sizeof(uint32_t), 1, fh); /* ByteRate */
  fwrite("\x01\x00", sizeof(char), 2, fh); /* BlockAlign = 1 */
  fwrite("\x08\x00", sizeof(char), 2, fh); /* BitsPerSample = 8 */
  fwrite("data", sizeof(char), 4, fh);
  fwrite(&subchunk2_size, sizeof(uint32_t), 1, fh);

  /* Samples: */
  for (i = 0; i < bitstream_n; i++) {
    if (bitstream[i] == '0') {
      for (j = 0; j < SAMPLE_LEN; j++) {
        fputc(UINT8_MAX, fh);
      }
      for (j = 0; j < SAMPLE_LEN; j++) {
        fputc(0, fh);
      }

    } else if (bitstream[i] == '1') {
      for (j = 0; j < (SAMPLE_LEN * 2); j++) {
        fputc(UINT8_MAX, fh);
      }
      for (j = 0; j < (SAMPLE_LEN * 2); j++) {
        fputc(0, fh);
      }
    }
  }
}



static void bitstream_byte(uint8_t byte)
{
  int i;
  crc16_update(byte);
  for (i = 0; i < 8; i++) {
    bitstream[bitstream_n++] = ((byte & 1) == 0) ? '0' : '1';
    byte >>= 1;
  }
  bitstream[bitstream_n++] = '1'; /* Stop Bit */
}



static void bitstream_bit(int bit)
{
  bitstream[bitstream_n++] = (bit == 0) ? '0' : '1';
}



static void block_generate(uint8_t block_type, uint16_t block_number,
  size_t block_size, uint8_t payload[])
{
  size_t i;
  uint8_t block_id;
  uint16_t block_bcc;

  for (block_id = 0; block_id < 2; block_id++) {
    for (i = 0; i < 240; i++) {
      bitstream_bit(1);
    }
    for (i = 0; i < 80; i++) {
      bitstream_bit(0); /* Sync Field */
    }
    bitstream_bit(1);
    bitstream_byte(0xFF); /* Preamble */
    bitstream_byte(0xAA);
    crc16 = 0x0000; /* Initialize CRC and start from here. */
    bitstream_byte(block_type);
    bitstream_byte(block_number >> 8);
    bitstream_byte(block_number & 0xFF);
    bitstream_byte(block_id);
    for (i = 0; i < block_size; i++) {
      bitstream_byte(payload[i]);
    }
    block_bcc = crc16; /* Save CRC until here. */
    bitstream_byte(block_bcc & 0xFF);
    bitstream_byte(block_bcc >> 8);
    bitstream_byte(0xAA); /* Postamble */
    bitstream_byte(0x00);
  }
}



int main(int argc, char *argv[])
{
  int c;
  int i;
  int data_n;
  uint16_t offset;
  uint8_t checksum;
  uint16_t block_number;
  int data_index;
  size_t name_len;
  FILE *fh;

  if (argc != 5) {
    fprintf(stderr, "Usage: %s <in> <out> <offset> <name>\n", argv[0]);
    return EXIT_FAILURE;
  }

  sscanf(argv[3], "%hx", &offset);
  name_len = strlen(argv[4]);
  if (name_len > 8) {
    name_len = 8;
  }

  /* Setup initial info used for header and EOF blocks: */
  for (i = 0; i < INFO_BLOCK_SIZE; i++) {
    info[i] = ' ';
  }
  memcpy(&info[4], argv[4], name_len);
  memcpy(&info[12], "BIN", 3);
  info[15] = 0x02;
  info[16] = 0x00;
  info[17] = 0x00;
  info[18] = 0x2A;
  info[20] = 0x32;
  info[21] = 0x53;
  memcpy(&info[24], "256", 3);
  memcpy(&info[32], "010100000000", 12);
  memcpy(&info[52], "HX-20", 5);
  info[76] = 0x00;
  info[77] = 0x00;
  info[78] = 0x00;
  info[79] = 0x00;

  fh = fopen(argv[1], "rb");
  if (fh == NULL) {
    fprintf(stderr, "Error: Cannot open '%s' for reading!\n", argv[1]);
    return EXIT_FAILURE;
  }

  /* Convert binary input to 68-byte chunks: */
  data_n = 0;
  while (1) {
    if (feof(fh)) {
      break;
    }
    if (data_n >= (DATA_MAX - CHUNK_SIZE)) {
      break;
    }

    /* Chunk header: */
    checksum = 0;
    data[data_n] = CHUNK_SIZE;
    checksum += data[data_n];
    data_n++;
    data[data_n] = offset >> 8;
    checksum += data[data_n];
    data_n++;
    data[data_n] = offset & 0xFF;
    checksum += data[data_n];
    data_n++;

    /* Chunk data: */
    for (i = 0; i < CHUNK_SIZE; i++) {
      c = fgetc(fh);
      if (c == EOF) {
        c = 0x00;
      }
      data[data_n] = c;
      data_n++;
      checksum += c;
    }

    /* Chunk checksum: */
    data[data_n++] = 0x100 - checksum;

    offset += CHUNK_SIZE;
  }
  fclose(fh);

  /* Leading bits: */
  for (i = 0; i < 5000; i++) {
    bitstream_bit(1);
  }

  /* Generate header blocks: */
  block_number = 0;
  memcpy(&info[0], "HDR1", 4);
  block_generate('H', block_number, INFO_BLOCK_SIZE, info);
  block_number++;

  /* Pause bits between header and data: */
  for (i = 0; i < 880; i++) {
    bitstream_bit(1);
  }

  /* Generate data blocks: */
  data_index = 0;
  while (data_index < data_n) {
    block_generate('D', block_number, DATA_BLOCK_SIZE, &data[data_index]);
    block_number++;
    data_index += DATA_BLOCK_SIZE;
  }

  /* Pause bits between data and EOF: */
  for (i = 0; i < 880; i++) {
    bitstream_bit(1);
  }

  /* Generate EOF blocks: */
  memcpy(&info[0], "EOF ", 4);
  block_generate('E', block_number, INFO_BLOCK_SIZE, info);

  /* Final bits: */
  for (i = 0; i < 5000; i++) {
    bitstream_bit(1);
  }

  /* Convert bitstream to WAV file: */
  fh = fopen(argv[2], "wb");
  if (fh == NULL) {
    fprintf(stderr, "Error: Cannot open '%s' for writing!\n", argv[2]);
    return EXIT_FAILURE;
  }
  wav_generate(fh);
  fclose(fh);

  return EXIT_SUCCESS;
}

