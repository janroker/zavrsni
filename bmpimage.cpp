#include "bmpimage.h"

#include <iostream>
#include <fstream>

using namespace std;

Pixel::Pixel() : r(0), g(0), b(0)
{
}

Pixel::Pixel(uint8_t b, uint8_t g, uint8_t r) : b(b), g(g), r(r)
{
}

Pixel::~Pixel()
{
}

std::ostream& operator<<(std::ostream & Str, Pixel const & v) 
{ 
    Str << static_cast<unsigned int>(v.b) << " " << static_cast<unsigned int>(v.g) << " " << static_cast<unsigned int>(v.r) << " ";
    return Str;
}

BMPImage::BMPImage(int width, int height) : width(width), height(height), data(vector<Pixel>(width * height))
{
}

BMPImage::~BMPImage()
{
}

BMPImage::BMPImage() : width(0), height(0), data(vector<Pixel>(0))
{
}

Pixel BMPImage::getPixel(int x, int y) const
{
    return data[y * width + x];
}

void BMPImage::setPixel(const Pixel &pixel, int x, int y)
{
    data[y * width + x].b = pixel.b;
    data[y * width + x].g = pixel.g;
    data[y * width + x].r = pixel.r;
}

void BMPImage::save(const char *path) const
{
    ofstream f;
    f.open(path, ios::out | ios::binary);

    if (!f.is_open())
    {
        cerr << "File " << path << " could not be opened!" << endl;
        return;
    }

    uint8_t padding[3] = {0, 0, 0};
    const int paddingAmount = ((4 - (this->width * 3) % 4) % 4);

    const uint32_t fileHeaderSize = 14;
    const uint32_t infoHeaderSize = 40;
    const uint32_t fileSize = fileHeaderSize + infoHeaderSize + (this->width * this->height * 3) + (paddingAmount * this->width);

    BmpHeader fileHeader; // default {'B', 'M'};
    fileHeader.sizeOfBitmapFile = fileSize;
    fileHeader.pixelDataOffset = fileHeaderSize + infoHeaderSize;

    BmpInfoHeader infoHeader; // size 40 default ok
    infoHeader.width = this->width;
    infoHeader.height = this->height;
    infoHeader.colorDepth = 24;
    // rest not specified --> default 0

    cout << "Writing heaaders size: " << sizeof(fileHeader) + sizeof(infoHeader) << endl;
    f.write(reinterpret_cast<char *>(&fileHeader), fileHeaderSize);
    f.write(reinterpret_cast<char *>(&infoHeader), infoHeaderSize);

    for (int yPos = 0; yPos < height; yPos++)
    {
        Pixel buf[this->width];
        for (int xPos = 0; xPos < width; xPos++)
        {
            buf[xPos] = this->getPixel(xPos, yPos);
        }
        f.write(reinterpret_cast<char *>(buf), sizeof(buf));
        f.write(reinterpret_cast<char *>(padding), paddingAmount);
    }

    f.close();
}

void BMPImage::read(const char *path)
{
    ifstream f;
    f.open(path, ios::in | ios::binary);

    if (!f.is_open())
    {
        cerr << "File " << path << " could not be opened!" << endl;
        f.close();
        return;
    }

    const uint32_t fileHeaderSize = 14;
    const uint32_t infoHeaderSize = 40;

    BmpHeader fileHeader;
    f.read(reinterpret_cast<char *>(&fileHeader), fileHeaderSize);

    if (fileHeader.bitmapSignatureBytes[0] != 'B' || fileHeader.bitmapSignatureBytes[1] != 'M')
    {
        cerr << "File " << path << " is not bitmap image!" << endl;
        return;
    }

    BmpInfoHeader infoHeader;
    f.read(reinterpret_cast<char *>(&infoHeader), infoHeaderSize);

    this->height = infoHeader.height;
    this->width = infoHeader.width;
    this->data.resize(height * width);

    const int paddingAmount = ((4 - (this->width * 3) % 4) % 4);

    for (int yPos = 0; yPos < height; yPos++)
    {
        Pixel buf[this->width];
        f.read(reinterpret_cast<char *>(buf), sizeof(buf));

        for (int xPos = 0; xPos < width; xPos++)
        {
            int pos = yPos * width + xPos;
            data[pos] = buf[xPos];
        }

        f.ignore(paddingAmount);
    }

    f.close();
}

Pixel *BMPImage::getData()
{
    return data.data();
}

int BMPImage::getWidth()
{
    return this->width;
}

int BMPImage::getHeight()
{
    return this->height;
}
