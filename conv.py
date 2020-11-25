# convert my png frames into charset data
import wx

app = wx.App()
imgpath="walk1.png"
img = wx.Image(imgpath, wx.BITMAP_TYPE_ANY)
width = img.GetWidth()
height = img.GetHeight()
pixels = img.GetData()

def getpxl(pixels, x, y):
  ofs = (width*y + x)*3
  return (pixels[ofs] << 16) + (pixels[ofs+1] << 8) + (pixels[ofs+2])

print('; ' + imgpath)
for y0 in range(0, height/8):
  for x0 in range(0, width/8):
    s = '.byt'
    for y in range(0, 8):
      val = 0
      for x in range(0, 8):
        if getpxl(pixels, x0*8+x, y0*8+y) == 0:
          val = val + 2 ** (7-x)
      if y != 0:
        s = s + ","
      s = s + " ${:02x}".format(val)
    print(s)

#import pdb; pdb.set_trace()
