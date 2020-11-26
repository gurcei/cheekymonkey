#!/usr/local/bin/python
# convert my png frames into charset data
import wx
import glob

def convImg(imgpath):
  global idx
  out = ''
  img = wx.Image(imgpath, wx.BITMAP_TYPE_ANY)
  width = img.GetWidth()
  height = img.GetHeight()
  pixels = img.GetData()

  def getpxl(pixels, x, y):
    ofs = (width*y + x)*3
    return (pixels[ofs] << 16) + (pixels[ofs+1] << 8) + (pixels[ofs+2])

  print('; ' + imgpath)
  out = out + '; ' + imgpath + '\n'
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
      out = out + s + '\n'
      idx = idx + 1

  #import pdb; pdb.set_trace()
  return out

app = wx.App()
imgs = glob.glob('*.png')
f = open('charset.s', 'wt')
fi = open('spridx.s', 'wt')
idx = 64

for img in imgs:
  fi.write('IMG_'+img.split('.')[0].upper() + ' = ${:02x}\n'.format(idx))
  out = convImg(img)
  f.write(out)

fi.close()
f.close()
