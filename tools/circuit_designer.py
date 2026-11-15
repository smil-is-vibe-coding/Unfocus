import numpy as np, json, sys
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

# Map coords: (x east, y north, h height). Converted to Godot (x, h, -y).
C = {}
C["monza"] = dict(width=22, scale=0.7, pts=[
 (0,100,0),(0,450,0),(0,780,0),                                   # main straight
 (4,890,0),(42,975,0),(48,1055,0),(22,1145,0),                   # Rettifilo chicane
 (40,1250,0),(160,1400,0),(320,1460,0),                          # Curva Grande
 (385,1460,0),(428,1412,0),(488,1405,0),(530,1440,0),            # Roggia chicane
 (600,1395,0),(648,1318,0),(668,1230,0),(670,1150,0),            # Lesmo 1-2
 (670,900,0),(670,780,0),                                        # Serraglio
 (652,700,0),(694,640,0),(694,580,0),(662,520,0),                # Ascari
 (662,350,0),(662,180,0),                                        # back straight
 (648,40,0),(585,-70,0),(465,-130,0),(320,-140,0),(180,-105,0),(80,-50,0),(22,15,0), # Parabolica
])
C["monaco"] = dict(width=16, scale=1.4, pts=[
 (0,0,0),(140,0,0),(250,8,0),                                    # pit straight
 (305,35,1),(318,95,3),                                          # Ste Devote
 (345,190,8),(395,290,12),                                       # Beau Rivage climb
 (418,355,13),(392,405,13),                                      # Massenet
 (418,450,13),(478,462,13),                                      # Casino
 (538,432,11),(566,372,8),                                       # down to Mirabeau
 (556,322,6),(520,300,5),(498,262,4),(526,226,3),                # Grand Hotel hairpin
 (580,212,2),                                                    # Portier
 (585,150,2),(555,90,2),(505,45,1),                              # tunnel
 (455,-10,0),(420,-42,0),(380,-30,0),(350,-64,0),                # Nouvelle chicane / Tabac
 (290,-84,0),(255,-62,0),(215,-90,0),(170,-75,0),                # Swimming pool
 (100,-100,0),(30,-105,0),(-25,-80,0),(-45,-35,0),               # Rascasse / Noghes
])
C["silverstone"] = dict(width=22, scale=0.8, pts=[
 (45,0,0),(260,0,0),                                             # Hamilton straight
 (390,-35,0),(450,-120,0),                                       # Copse
 (470,-200,0),(424,-278,0),(480,-355,0),(434,-432,0),(484,-505,0),  # Maggotts/Becketts
 (525,-575,0),(560,-690,0),(590,-775,0),                         # Chapel + Hangar straight
 (600,-830,0),(560,-890,0),                                      # Stowe
 (485,-905,0),(432,-878,0),(378,-905,0),(330,-898,0),            # Vale / Club
 (240,-860,0),(150,-790,0),                                      # Abbey
 (110,-700,0),(60,-690,0),(20,-640,0),                           # Village / Loop
 (30,-520,0),(25,-330,0),                                        # Wellington straight
 (-15,-250,0),(-70,-210,0),(-82,-140,0),(-55,-75,0),             # Brooklands / Luffield
 (-15,-22,0),                                                    # Woodcote
])
C["spa"] = dict(width=20, scale=1.2, pts=[
 (0,-60,0),(0,120,0),                                            # start straight
 (15,200,0),(50,218,-1),(72,185,-2),                             # La Source hairpin
 (72,60,-5),(72,-80,-10),                                        # downhill
 (58,-140,-12),(95,-190,-4),(85,-250,6),                         # Eau Rouge / Raidillon
 (150,-450,10),(230,-650,12),                                    # Kemmel straight
 (250,-712,12),(286,-730,11),(290,-778,10),                      # Les Combes
 (300,-830,9),(270,-865,8),                                      # Malmedy
 (215,-880,6),(172,-855,5),(165,-810,4),                         # Rivage hairpin
 (150,-740,2),(110,-702,1),(60,-702,0),                          # Pouhon
 (0,-680,0),(-30,-630,0),(-35,-560,0),                           # Fagnes / Stavelot
 (-30,-420,0),(-20,-300,0),                                      # Blanchimont
 (-18,-245,0),(16,-196,0),(-8,-150,0),(0,-112,0),               # Bus Stop chicane
])
C["suzuka"] = dict(width=20, scale=1.3, pts=[
 (265,-142,0),(330,-140,0),                                      # S/F straight
 (380,-110,0),(420,-40,0),                                       # T1-T2
 (410,40,0),(370,90,0),(320,78,1),(280,120,1),(230,98,2),(190,130,2),  # Esses
 (140,120,3),(100,90,3),(60,50,2),                               # Dunlop / Degner
 (0,0,0),                                                        # under the bridge
 (-70,-60,0),(-150,-100,1),                                      # to the hairpin
 (-230,-112,2),(-275,-90,2),(-270,-48,3),                        # Hairpin
 (-260,20,4),(-290,90,6),(-320,140,8),                           # right sweep
 (-300,180,10),(-240,188,12),(-180,155,14),                      # Spoon
 (-90,80,15),(0,0,15),                                           # back straight over the bridge
 (60,-55,11),(110,-100,6),                                       # 130R
 (142,-112,2),(176,-158,1),(218,-142,0),                         # Casio chicane
])

def bez(p0,h0,h1,p1,t):
    a=p0; b=p0+h0; c=p1+h1; d=p1
    return (1-t)**3*a+3*(1-t)**2*t*b+3*(1-t)*t**2*c+t**3*d

def bake(pts, step=2.0):
    P=[np.array(p,float) for p in pts]; n=len(P); out=[]
    for i in range(n):
        p0=P[i]; p1=P[(i+1)%n]
        h0=(P[(i+1)%n]-P[(i-1)%n])/6; h1=-(P[(i+2)%n]-P[i])/6
        L=np.linalg.norm(p1-p0); k=max(4,int(L/step))
        for j in range(k): out.append(bez(p0,h0,h1,p1,j/k))
    return np.array(out)

def godot_pts(c):
    s=c["scale"]
    return [(round(x*s,1), round(h,1), round(-y*s,1)) for x,y,h in c["pts"]]

def check(name, c):
    g=np.array(godot_pts(c),float)
    B=bake(g)
    seg=np.linalg.norm(np.diff(np.vstack([B,B[:1]]),axis=0),axis=1)
    L=seg.sum(); cum=np.concatenate([[0],np.cumsum(seg)])[:-1]
    w=c["width"]; issues=[]
    # curvature radius (xz)
    xz=B[:,[0,2]]; n=len(xz); minR=1e9; at=0
    for i in range(n):
        a,b,cc=xz[i-3],xz[i],xz[(i+3)%n]
        ab=np.linalg.norm(b-a); bc=np.linalg.norm(cc-b); ac=np.linalg.norm(cc-a)
        cr=abs((b[0]-a[0])*(cc[1]-a[1])-(b[1]-a[1])*(cc[0]-a[0]))
        R=ab*bc*ac/(2*cr) if cr>1e-6 else 1e9
        if R<minR: minR=R; at=cum[i]
    if minR < w*0.75: issues.append(f"tight R={minR:.1f} at {at:.0f}m")
    # proximity
    idx=np.arange(0,n,3)
    for ii in idx:
        d=np.linalg.norm(xz[idx]-xz[ii],axis=1)
        sep=np.abs(cum[idx]-cum[ii]); sep=np.minimum(sep,L-sep)
        dh=np.abs(B[idx,1]-B[ii,1])
        bad=(d<w+8)&(sep>w*5)&(dh<12)
        if bad.any():
            jj=idx[np.argmax(bad)]
            issues.append(f"overlap {cum[ii]:.0f}m~{cum[jj]:.0f}m d={d[bad].min():.0f}")
            break
    return L,minR,issues,B

names=sys.argv[1:] or list(C)
fig,axs=plt.subplots(1,len(names),figsize=(5*len(names),5))
if len(names)==1: axs=[axs]
for ax,name in zip(axs,names):
    L,minR,iss,B=check(name,C[name])
    print(f"{name:12s} len={L:6.0f}m minR={minR:5.1f} width={C[name]['width']} {'OK' if not iss else iss}")
    ax.scatter(B[:,0],B[:,2],c=B[:,1],s=2,cmap="plasma")
    ax.plot(B[0,0],B[0,2],"go",ms=8); ax.annotate("",xy=(B[15,0],B[15,2]),xytext=(B[0,0],B[0,2]),arrowprops=dict(color="g"))
    ax.set_aspect("equal"); ax.invert_yaxis(); ax.set_title(f"{name} {L:.0f}m")
plt.tight_layout(); plt.savefig(__file__.replace(".py",".png"),dpi=70)
json.dump({k:dict(width=v["width"],pts=godot_pts(v)) for k,v in C.items()}, open(__file__.replace(".py",".json"),"w"))
