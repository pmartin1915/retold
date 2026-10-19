from PIL import Image, ImageDraw, ImageFont
import math,sys
SS=3; N=1024*SS
BG=(0x7B,0x4B,0x34); CREAM=(0xF9,0xF0,0xE3); GOLD=(0xE9,0xB9,0x6E)
FONT='C:/Windows/Fonts/georgiab.ttf'
def base():
    im=Image.new('RGB',(N,N),BG); return im,ImageDraw.Draw(im)
def glyphR(d,cx,cy,size,col):
    f=ImageFont.truetype(FONT,int(size*SS))
    bb=d.textbbox((0,0),'R',font=f); w=bb[2]-bb[0]; h=bb[3]-bb[1]
    d.text((cx-w/2-bb[0],cy-h/2-bb[1]),'R',font=f,fill=col)
    return (cx-w/2,cy-h/2,cx+w/2,cy+h/2)
def A():
    im,d=base()
    box=glyphR(d,N/2,N*0.40,650,CREAM)
    # waveform bars beneath
    hs=[0.5,0.9,0.6,1.0,0.7,0.95,0.55,0.8,0.45]
    n=len(hs); bw=40*SS; gap=36*SS; total=n*bw+(n-1)*gap; x=(N-total)/2; cy=N*0.805
    for k,h in enumerate(hs):
        hh=h*150*SS
        d.rounded_rectangle([x,cy-hh/2,x+bw,cy+hh/2],radius=bw/2,fill=GOLD); x+=bw+gap
    return im.resize((1024,1024),Image.LANCZOS)
def C():
    im,d=base()
    box=glyphR(d,N*0.45,N*0.52,640,CREAM)
    # voice arcs emanating from the R's upper right
    cx,cy=box[2]-20*SS,box[1]+120*SS
    for i,r in enumerate([110,200,290]):
        rr=r*SS; d.arc([cx-rr,cy-rr,cx+rr,cy+rr],-55,55,fill=GOLD,width=int(34*SS))
        for a in (-55,55):
            x=cx+rr*math.cos(math.radians(a)); y=cy+rr*math.sin(math.radians(a)); e=17*SS
            d.ellipse([x-e,y-e,x+e,y+e],fill=GOLD)
    return im.resize((1024,1024),Image.LANCZOS)
A().save('A.png'); C().save('C.png')
W=Image.new('RGB',(2*520,520),'white')
W.paste(Image.open('A.png').resize((500,500)),(10,10)); W.paste(Image.open('C.png').resize((500,500)),(530,10)); W.save('cmp.png')
