#ifndef BMPIMAGE_H
#define BMPIMAGE_H

#include <vector>
#include <cstdint>
#include <ostream>
//////////////////////////////////////////////
///////// BMP headers
//////////////////////////////////////////////

#pragma pack(push, 2)
struct BmpHeader
{ // 14 bytes
    char bitmapSignatureBytes[2] = {'B', 'M'};
    uint32_t sizeOfBitmapFile = 54 + 786432; // total size of bitmap file
    uint32_t reservedBytes = 0;
    uint32_t pixelDataOffset = 54;
};

struct BmpInfoHeader
{ // 7 different versions
    uint32_t sizeOfThisHeader = 40;
    int32_t width = 512;              // in pixels
    int32_t height = 512;             // in pixels
    uint16_t numberOfColorPlanes = 1; // must be 1
    uint16_t colorDepth = 24;
    uint32_t compressionMethod = 0;      // generally ignored
    uint32_t rawBitmapDataSize = 0;      // generally ignored
    int32_t horizontalResolution = 0; // in pixel per meter
    int32_t verticalResolution = 0;   // in pixel per meter
    uint32_t colorTableEntries = 0;      // the number of colors in the color palette, or 0 to default to 2n
    uint32_t importantColors = 0;        // the number of important colors used, or 0 when every color is important; generally ignored
};
#pragma pack(pop)

#pragma pack(push, 1)
struct Pixel // obrnuto je... rgb -> bgr
{
    uint8_t b, g, r;

    Pixel();
    Pixel(uint8_t b, uint8_t g, uint8_t r);
    ~Pixel();

    friend std::ostream &operator<<(std::ostream & Str, Pixel const & v);
};
#pragma pack(pop)



//////////////////////////////////////////////
///////// BMP Image
//////////////////////////////////////////////

// padding = ((4 - (width * 3) % 4) % 4);       ===> 2 puta % 4 jer (4 - 0 = 4)
// filesize = header (14) + infoHeader (40) + (data[width * height * 3] + padding * width)
class BMPImage
{
public:
    BMPImage(int width, int height);
    ~BMPImage();
    BMPImage();

    Pixel getPixel(int x, int y) const;
    void setPixel(const Pixel &pixel, int x, int y);
    void save(const char *path) const;
    void read(const char *path);
    Pixel *getData();
    int getWidth();
    int getHeight();

private:
    int width;
    int height;
    std::vector<Pixel> data;
};

#endif // BMPIMAGE_H
