#include "bmpimage.h"
#include "toojpeg/toojpeg.h"
#include <vector>
#include <fstream>
#include <iostream>

using namespace std;

static unsigned char buf[1024];
static int count = 0;
static ofstream f;

int main(void)
{
    // const int width = 640;
    // const int height = 480;

    // BMPImage img(width, height);

    // for (int y = 0; y < height; y++)
    // {
    //     for (int x = 0; x < width; x++)
    //     {
    //         img.setPixel(Pixel(((float)x) / width * 255, 255 - ((float)x) / width * 255, ((float)y) / height * 255), x, y);
    //     }
    // }
    BMPImage img;
    img.read("snail.bmp");

    f.open("img.jpg", ios::out | ios::binary);

    auto myOutput = [](unsigned char oneByte) {
        if (count >= 1024)
        {
            f.write(reinterpret_cast<char *>(buf), count);
            count = 0;
        }

        buf[count++] = oneByte;
    };

    int width = img.getWidth();
    int height = img.getHeight();
    uint8_t data[width * height * 3];
    for (int yIn = 0, y = height-1; y >= 0; y--, yIn++)
    {
        for (int x = 0; x < width; x++)
        {
            Pixel pix = img.getPixel(x, y);
            int pos = (yIn * width * 3) + (x * 3);
            data[pos] = pix.r;
            data[pos + 1] = pix.g;
            data[pos + 2] = pix.b;
        }
    }

    TooJpeg::writeJpeg(myOutput, data, static_cast<unsigned short>(width), static_cast<unsigned short>(height));
    if (count != 0)
        f.write(reinterpret_cast<char *>(buf), count);

    f.close();

    // img.save("img.bmp");

    // BMPImage copy(0, 0);
    // copy.read("img.bmp");
    // copy.save("copy.bmp");
}