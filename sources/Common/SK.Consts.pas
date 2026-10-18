unit SK.Consts;

interface

type
  TGenreMapping = record
    SourceID, TargetID: Integer;
  end;

const
  // Public identity used by the UI, HTTP requests and exported filenames.
  AppBrand = 'RetroScraper';
  AppVersion = '0.2.2';
  AppUserAgent = AppBrand + '/' + AppVersion;
  // Legacy storage identifiers preserve existing settings and native keyring access.
  AppDataDirectoryName = 'RetroScraper';
  CredentialServiceID = 'org.skraperfmx.Credentials';
  CredentialMarker = 'SkraperFMX native keyring v1';
  ConfigFileName = 'retroscraper.config.json';
  LegacyConfigFileName = 'skraper.config.json';
  ExportLogFileName = 'retroscraper-log.txt';
  ConfigSchemaVersion = 3;
  CredentialsFileName = 'credentials.dat';
  DefaultConfigPath = 'Resources/default.config.json';
  SystemsCatalogPath = 'Resources/systems.json';
  ResourceManifestPath = 'Resources/manifest.json';
  LogInfoIconPath = 'Resources/Icons/info-24-regular.fmxpart';
  LogSuccessIconPath = 'Resources/Icons/checkmark-circle-24-regular.fmxpart';
  LogErrorIconPath = 'Resources/Icons/error-circle-24-regular.fmxpart';
  ScreenScraperAPIBaseURL = 'https://api.screenscraper.fr/api2/';
  ScreenScraperWebsite = 'https://www.screenscraper.fr';
  ScreenScraperMediaHost = 'screenscraper.fr';
  ScreenScraperDiscordURL = 'https://discordapp.com/invite/VNNBkaq';
  UserInfoEndpoint = 'ssuserInfos.php';
  SystemsEndpoint = 'systemesListe.php';
  GameInfoEndpoint = 'jeuInfos.php';
  HTTPOK = 200;
  HTTPUnauthorized = 401;
  HTTPForbidden = 403;
  HTTPNotFound = 404;
  HTTPServerLocked = 423;
  HTTPUpgradeRequired = 426;
  HTTPTooManyRequests = 429;
  HTTPDailyQuotaExceeded = 430;
  HTTPFailedRequestQuotaExceeded = 431;
  ScreenScraperCredentialKeys: array[0..3] of string = ('devid', 'devpassword', 'ssid', 'sspassword');
  ReusableMediaFormats: array[0..7] of string = ('png', 'jpg', 'jpeg', 'mp4', 'avi', 'mkv', 'mov', 'pdf');
  DownloadMediaFormats: array[0..11] of string = ('png', 'jpg', 'jpeg', 'mp4', 'avi', 'mkv', 'mov', 'pdf', 'ini', 'cfg', 'zip', 'p2k.cfg');
  PreviewImageExtensions: array[0..3] of string = ('.png', '.jpg', '.jpeg', '.bmp');
  HTTPConnectionTimeoutMs = 15000;
  HTTPResponseTimeoutMs = 30000;
  HTTPRetryCount = 2;
  MinimumScrapeWorkers = 4;
  APIBackoffMs = 500;
  MediaBackoffMs = 250;
  DefaultCacheDays = 3;
  UnlimitedCacheDays = 44739242;
  QuotaRefreshIntervalMs = 60000;
  CancellationPollMs = 25;
  ResourceLockPollMs = 50;
  WorkerPollMs = 20;
  ProcessPollMs = 25;
  FrontendPollMs = 50;
  FrontendStopTimeoutMs = 5000;
  SSHTimeoutMs = 15000;
  SSHConnectTimeoutSeconds = 10;
  PosixSSHPath = '/usr/bin/ssh';
  PosixProcessKillPath = '/usr/bin/pkill';
  PosixProcessQueryPath = '/usr/bin/pgrep';
  MacOSOpenPath = '/usr/bin/open';
  LinuxOpenPath = '/usr/bin/xdg-open';
  LinuxSecretLibrary = 'libsecret-1.so.0';
  BrowserTimeoutMs = 10000;
  PreviewIntervalMs = 256;
  PreviewJitterMs = 256;
  MaxVisibleLogEntries = 200;
  DefaultMediaWidth = 800;
  DefaultMediaHeight = 600;
  MixPreviewWidth = 320;
  MixPreviewHeight = 240;
  MixDefaultWidth = 1280;
  MixDefaultHeight = 960;
  MixIncludeDepthLimit = 16;
  MixDrawingDepthLimit = 32;
  MixParentDepthLimit = 256;
  TextFontSizeUpperBound = 1001;
  TextMeasureHeight = 1000000;
  TextOutlineScale = 200;
  HashBufferSize = 1024 * 1024;
  MaxGdiDescriptorSize = 10240;
  LargeRomHashThreshold = 20971520;
  CRC32InitialValue: Cardinal = $FFFFFFFF;
  CRC32Polynomial: Cardinal = $EDB88320;
  SystemIDDOS = 135;
  SystemIDScummVM = 123;
  SecurityFramework = '/System/Library/Frameworks/Security.framework/Security';
  SettingsGroups: array[0..5] of string = ('GameList', 'GamesAndRoms', 'MetaData', 'Medias', 'Miscellaneous', 'Overlays');
  SettingsGroupBits: array[0..5] of Integer = (1, 2, 4, 8, 16, 32);
  ScreenScraperImageTypes: array[0..16] of string = ('ss', 'sstitle', 'fanart', 'box-2D', 'box-2D-side', 'box-2D-back', 'box-3D', 'box-texture', 'support-2D', 'support-texture', 'wheel', 'wheel-carbon', 'wheel-steel', 'steamgrid', 'screenmarquee', 'screenmarqueesmall', 'marquee');
  ScreenScraperExtendedImageTypes: array[17..44] of string = ('system:bezel-4-3',
    'system:bezel-16-9', 'system:wheel', 'system:wheel-carbon', 'system:wheel-steel',
    'system:logo-monochrome', 'system:icon', 'system:minicon', 'system:photo',
    'system:illustration', 'system:controller', 'system:screenmarquee', 'system:background',
    'classification:pictoliste', 'joueurs:pictoliste', 'note:pictoliste', 'mixrbv1',
    'mixrbv2', 'developpeur:pictocouleur', 'developpeur:pictomonochrome',
    'editeur:pictocouleur', 'editeur:pictomonochrome', 'genre:pictoliste#1',
    'genre:pictoliste#2', 'genre:pictoliste#3', 'genre:pictomonochrome#1',
    'genre:pictomonochrome#2', 'genre:pictomonochrome#3');
  BuiltInMixFiles: array[0..6] of string = ('Best Screenshot.xml', '2 Images Mix [HD][4-3].xml', '3 Images Mix [HD][4-3].xml', '4 Images Mix [HD][4-3].xml', '5 Images Mix [HD][4-3].xml', 'Recalbox V1.xml', 'Recalbox V2.xml');
  MixSamplePrefixes: array[0..5] of string = ('snes', 'gb', 'megadrive', 'dc', 'arcadeh', 'arcadev');
  RegionAliases =
    '029=029;419=419;ad=ad;ae=ae;af=af;afghanistan=af;ag=ag;ai=ai;al=al;albania=al;algeria=dz;am=am;americansamoa=as;andorra=ad;angola=ao;anguilla=ai;antig' +
    'ua&barbuda=ag;ao=ao;ar=ar;argentina=ar;armenia=am;aruba=aw;as=as;at=at;au=au;australia=au;austria=at;aw=aw;ax=ax;az=az;azerbaijan=az;ba=ba;bahamas=bs;' +
    'bahrain=bh;bangladesh=bd;barbados=bb;bb=bb;bd=bd;be=be;belarus=by;belgium=be;belize=bz;benin=bj;bermuda=bm;bf=bf;bg=bg;bh=bh;bhutan=bt;bi=bi;bj=bj;bl=' +
    'bl;bm=bm;bn=bn;bo=bo;bolivia=bo;bonaire,sinteustatiusandsaba=bq;bosnia&herzegovina=ba;botswana=bw;bq=bq;br=br;brazil=br;britishindianoceanterritory=io' +
    ';britishvirginislands=vg;brunei=bn;bs=bs;bt=bt;bulgaria=bg;burkinafaso=bf;burundi=bi;bw=bw;by=by;bz=bz;ca=ca;caboverde=cv;cambodia=kh;cameroon=cm;cana' +
    'da=ca;caribbean=029;caymanislands=ky;cc=cc;cd=cd;centralafricanrepublic=cf;cf=cf;cg=cg;ch=ch;chad=td;chile=cl;china=cn;christmasisland=cx;ci=ci;ck=ck;' +
    'cl=cl;cm=cm;cn=cn;co=co;cocos(keeling)islands=cc;colombia=co;comoros=km;congo=cg;congo(drc)=cd;cookislands=ck;costarica=cr;cr=cr;croatia=hr;cu=cu;cuba' +
    '=cu;curaçao=cw;cv=cv;cw=cw;cx=cx;cy=cy;cyprus=cy;cz=cz;czechia=cz;côted’ivoire=ci;de=de;denmark=dk;dj=dj;djibouti=dj;dk=dk;dm=dm;do=do;dominica=dm;dom' +
    'inicanrepublic=do;dz=dz;e=eu;ec=ec;ecuador=ec;ee=ee;eg=eg;egypt=eg;elsalvador=sv;equatorialguinea=gq;er=er;eritrea=er;estonia=ee;eswatini=sz;et=et;eth' +
    'iopia=et;eu=eu;europe=eu;falklandislands=fk;faroeislands=fo;fi=fi;fiji=fj;finland=fi;fj=fj;fk=fk;fm=fm;fo=fo;fr=fr;france=fr;frenchguiana=gf;frenchpol' +
    'ynesia=pf;ga=ga;gabon=ga;gambia=gm;gd=gd;ge=ge;georgia=ge;germany=de;gf=gf;gg=gg;gh=gh;ghana=gh;gi=gi;gibraltar=gi;gl=gl;gm=gm;gn=gn;gp=gp;gq=gq;gr=gr' +
    ';greece=gr;greenland=gl;grenada=gd;gt=gt;gu=gu;guadeloupe=gp;guam=gu;guatemala=gt;guernsey=gg;guinea=gn;guinea-bissau=gw;guyana=gy;gw=gw;gy=gy;haiti=h' +
    't;hk=hk;hn=hn;honduras=hn;hongkong=hk;hongkongsar=hk;hr=hr;ht=ht;hu=hu;hungary=hu;iceland=is;id=id;ie=ie;il=il;im=im;in=in;india=in;indonesia=id;io=io' +
    ';iq=iq;ir=ir;iran=ir;iraq=iq;ireland=ie;is=is;isleofman=im;israel=il;it=it;italy=it;j=jp;jamaica=jm;japan=jp;je=je;jersey=je;jm=jm;jo=jo;jordan=jo;jp=' +
    'jp;kazakhstan=kz;ke=ke;kenya=ke;kg=kg;kh=kh;ki=ki;kiribati=ki;km=km;kn=kn;korea=kr;kosovo=xk;kp=kp;kr=kr;kuwait=kw;kw=kw;ky=ky;kyrgyzstan=kg;kz=kz;la=' +
    'la;laos=la;latinamerica=419;latvia=lv;lb=lb;lc=lc;lebanon=lb;lesotho=ls;li=li;liberia=lr;libya=ly;liechtenstein=li;lithuania=lt;lk=lk;lr=lr;ls=ls;lt=l' +
    't;lu=lu;luxembourg=lu;lv=lv;ly=ly;ma=ma;macaosar=mo;madagascar=mg;malawi=mw;malaysia=my;maldives=mv;mali=ml;malta=mt;marshallislands=mh;martinique=mq;' +
    'mauritania=mr;mauritius=mu;mayotte=yt;mc=mc;md=md;me=me;mexico=mx;mf=mf;mg=mg;mh=mh;micronesia=fm;mk=mk;ml=ml;mm=mm;mn=mn;mo=mo;moldova=md;monaco=mc;m' +
    'ongolia=mn;montenegro=me;montserrat=ms;morocco=ma;mozambique=mz;mp=mp;mq=mq;mr=mr;ms=ms;mt=mt;mu=mu;mv=mv;mw=mw;mx=mx;my=my;myanmar=mm;mz=mz;na=na;nam' +
    'ibia=na;nauru=nr;nc=nc;ne=ne;nepal=np;netherlands=nl;newcaledonia=nc;newzealand=nz;nf=nf;ng=ng;ni=ni;nicaragua=ni;niger=ne;nigeria=ng;niue=nu;nl=nl;no' +
    '=no;norfolkisland=nf;northernmarianaislands=mp;northkorea=kp;northmacedonia=mk;norway=no;np=np;nr=nr;nu=nu;nz=nz;om=om;oman=om;pa=pa;pakistan=pk;palau' +
    '=pw;palestinianauthority=ps;panama=pa;papuanewguinea=pg;paraguay=py;pe=pe;peru=pe;pf=pf;pg=pg;ph=ph;philippines=ph;pitcairnislands=pn;pk=pk;pl=pl;pm=p' +
    'm;pn=pn;poland=pl;portugal=pt;pr=pr;ps=ps;pt=pt;puertorico=pr;pw=pw;py=py;qa=qa;qatar=qa;re=re;ro=ro;romania=ro;rs=rs;ru=ru;russia=ru;rw=rw;rwanda=rw;' +
    'réunion=re;sa=sa;samoa=ws;sanmarino=sm;saudiarabia=sa;sb=sb;sc=sc;sd=sd;se=se;senegal=sn;serbia=rs;seychelles=sc;sg=sg;sh=sh;si=si;sierraleone=sl;sing' +
    'apore=sg;sintmaarten=sx;sj=sj;sk=sk;sl=sl;slovakia=sk;slovenia=si;sm=sm;sn=sn;so=so;solomonislands=sb;somalia=so;southafrica=za;southkorea=kr;southsud' +
    'an=ss;sp=sp;spain=sp;sr=sr;srilanka=lk;ss=ss;st=st;st.barthélemy=bl;st.kitts&nevis=kn;st.lucia=lc;st.martin=mf;st.pierre&miquelon=pm;st.vincent&grenad' +
    'ines=vc;sthelena,ascension,tristandacunha=sh;sudan=sd;suriname=sr;sv=sv;svalbard&janmayen=sj;sweden=se;switzerland=ch;sx=sx;sy=sy;syria=sy;sz=sz;sãoto' +
    'mé&príncipe=st;taiwan=tw;tajikistan=tj;tanzania=tz;tc=tc;td=td;tg=tg;th=th;thailand=th;timor-leste=tl;tj=tj;tk=tk;tl=tl;tm=tm;tn=tn;to=to;togo=tg;toke' +
    'lau=tk;tonga=to;tr=tr;trinidad&tobago=tt;tt=tt;tunisia=tn;turkmenistan=tm;turks&caicosislands=tc;tuvalu=tv;tv=tv;tw=tw;tz=tz;türkiye=tr;u=us;u.s.outly' +
    'ingislands=um;u.s.virginislands=vi;ua=ua;ug=ug;uganda=ug;uk=uk;ukraine=ua;um=um;unitedarabemirates=ae;unitedkingdom=uk;unitedstates=us;uruguay=uy;us=u' +
    's;usa=us;uy=uy;uz=uz;uzbekistan=uz;va=va;vanuatu=vu;vaticancity=va;vc=vc;ve=ve;venezuela=ve;vg=vg;vi=vi;vietnam=vn;vn=vn;vu=vu;wallis&futuna=wf;wf=wf;' +
    'wor=wor;world=wor;ws=ws;xk=xk;ye=ye;yemen=ye;yt=yt;za=za;zambia=zm;zimbabwe=zw;zm=zm;zw=zw;ålandislands=ax';
  RomFlags: array[0..10] of string = ('beta', 'demo', 'alt', 'best', 'romcloneof', 'hack', 'trad', 'unl', 'proto', 'romnumsupport', 'clonetypes');
  RomFlagBits: array[0..10] of Integer = (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048);
  ProcessEnvironmentNames: array[0..10] of string = ('HOME', 'PATH', 'LANG', 'DISPLAY', 'WAYLAND_DISPLAY', 'XDG_RUNTIME_DIR',
    'DBUS_SESSION_BUS_ADDRESS', 'SSH_AUTH_SOCK', 'USER', 'LOGNAME', 'XAUTHORITY');
  SubGenreMappings: array[0..104] of TGenreMapping = (
    (SourceID: 1; TargetID: 263),
    (SourceID: 7; TargetID: 257),
    (SourceID: 14; TargetID: 262),
    (SourceID: 28; TargetID: 1537),
    (SourceID: 32; TargetID: 261),
    (SourceID: 79; TargetID: 260),
    (SourceID: 425; TargetID: 266),
    (SourceID: 1861; TargetID: 1540),
    (SourceID: 2648; TargetID: 1027),
    (SourceID: 2650; TargetID: 1538),
    (SourceID: 2846; TargetID: 1538),
    (SourceID: 2847; TargetID: 1538),
    (SourceID: 2851; TargetID: 260),
    (SourceID: 2852; TargetID: 1538),
    (SourceID: 2853; TargetID: 1538),
    (SourceID: 2861; TargetID: 1540),
    (SourceID: 2867; TargetID: 1538),
    (SourceID: 2870; TargetID: 260),
    (SourceID: 2871; TargetID: 1537),
    (SourceID: 2874; TargetID: 262),
    (SourceID: 2875; TargetID: 1538),
    (SourceID: 2876; TargetID: 260),
    (SourceID: 2877; TargetID: 1538),
    (SourceID: 2878; TargetID: 1538),
    (SourceID: 2883; TargetID: 1538),
    (SourceID: 2884; TargetID: 1537),
    (SourceID: 2885; TargetID: 262),
    (SourceID: 2887; TargetID: 258),
    (SourceID: 2888; TargetID: 1537),
    (SourceID: 2889; TargetID: 260),
    (SourceID: 2892; TargetID: 260),
    (SourceID: 2893; TargetID: 1028),
    (SourceID: 2895; TargetID: 1027),
    (SourceID: 2896; TargetID: 258),
    (SourceID: 2897; TargetID: 257),
    (SourceID: 2899; TargetID: 260),
    (SourceID: 2900; TargetID: 260),
    (SourceID: 2901; TargetID: 1538),
    (SourceID: 2902; TargetID: 1538),
    (SourceID: 2906; TargetID: 1538),
    (SourceID: 2909; TargetID: 257),
    (SourceID: 2910; TargetID: 1028),
    (SourceID: 2911; TargetID: 1028),
    (SourceID: 2913; TargetID: 1538),
    (SourceID: 2914; TargetID: 262),
    (SourceID: 2915; TargetID: 257),
    (SourceID: 2918; TargetID: 1538),
    (SourceID: 2919; TargetID: 1540),
    (SourceID: 2920; TargetID: 262),
    (SourceID: 2921; TargetID: 1028),
    (SourceID: 2922; TargetID: 262),
    (SourceID: 2924; TargetID: 1537),
    (SourceID: 2925; TargetID: 266),
    (SourceID: 2929; TargetID: 1540),
    (SourceID: 2933; TargetID: 1538),
    (SourceID: 2934; TargetID: 1028),
    (SourceID: 2937; TargetID: 258),
    (SourceID: 2938; TargetID: 1028),
    (SourceID: 2940; TargetID: 1028),
    (SourceID: 2943; TargetID: 1537),
    (SourceID: 2945; TargetID: 261),
    (SourceID: 2947; TargetID: 1540),
    (SourceID: 2948; TargetID: 1538),
    (SourceID: 2953; TargetID: 1028),
    (SourceID: 2955; TargetID: 260),
    (SourceID: 2957; TargetID: 262),
    (SourceID: 2960; TargetID: 1538),
    (SourceID: 2966; TargetID: 1538),
    (SourceID: 2968; TargetID: 1538),
    (SourceID: 2970; TargetID: 1538),
    (SourceID: 2971; TargetID: 1538),
    (SourceID: 2973; TargetID: 1537),
    (SourceID: 2988; TargetID: 259),
    (SourceID: 3024; TargetID: 259),
    (SourceID: 3026; TargetID: 258),
    (SourceID: 3028; TargetID: 1538),
    (SourceID: 3034; TargetID: 1540),
    (SourceID: 3192; TargetID: 1027),
    (SourceID: 3237; TargetID: 514),
    (SourceID: 20670; TargetID: 513),
    (SourceID: 20672; TargetID: 514),
    (SourceID: 20674; TargetID: 515),
    (SourceID: 20676; TargetID: 516),
    (SourceID: 20678; TargetID: 517),
    (SourceID: 20680; TargetID: 518),
    (SourceID: 20682; TargetID: 1025),
    (SourceID: 20684; TargetID: 1026),
    (SourceID: 20688; TargetID: 769),
    (SourceID: 20690; TargetID: 770),
    (SourceID: 20692; TargetID: 771),
    (SourceID: 20694; TargetID: 772),
    (SourceID: 20696; TargetID: 773),
    (SourceID: 20698; TargetID: 768),
    (SourceID: 20700; TargetID: 1028),
    (SourceID: 20702; TargetID: 1029),
    (SourceID: 23258; TargetID: 1538),
    (SourceID: 23278; TargetID: 1538),
    (SourceID: 25726; TargetID: 1538),
    (SourceID: 26363; TargetID: 260),
    (SourceID: 26635; TargetID: 1538),
    (SourceID: 26638; TargetID: 1538),
    (SourceID: 27530; TargetID: 1537),
    (SourceID: 28579; TargetID: 266),
    (SourceID: 28582; TargetID: 266),
    (SourceID: 28585; TargetID: 266)
  );
  GenreMappings: array[0..55] of TGenreMapping = (
    (SourceID: 8; TargetID: 768),
    (SourceID: 10; TargetID: 256),
    (SourceID: 13; TargetID: 512),
    (SourceID: 26; TargetID: 2816),
    (SourceID: 27; TargetID: 1280),
    (SourceID: 30; TargetID: 4352),
    (SourceID: 31; TargetID: 1792),
    (SourceID: 33; TargetID: 2048),
    (SourceID: 34; TargetID: 3840),
    (SourceID: 39; TargetID: 0),
    (SourceID: 40; TargetID: 1024),
    (SourceID: 42; TargetID: 2560),
    (SourceID: 171; TargetID: 2304),
    (SourceID: 320; TargetID: 3584),
    (SourceID: 323; TargetID: 0),
    (SourceID: 685; TargetID: 1536),
    (SourceID: 2646; TargetID: 256),
    (SourceID: 2647; TargetID: 2048),
    (SourceID: 2649; TargetID: 3328),
    (SourceID: 2844; TargetID: 256),
    (SourceID: 2855; TargetID: 0),
    (SourceID: 2860; TargetID: 3584),
    (SourceID: 2864; TargetID: 2816),
    (SourceID: 2869; TargetID: 2048),
    (SourceID: 2872; TargetID: 3584),
    (SourceID: 2879; TargetID: 0),
    (SourceID: 2881; TargetID: 256),
    (SourceID: 2882; TargetID: 2048),
    (SourceID: 2890; TargetID: 1024),
    (SourceID: 2891; TargetID: 2816),
    (SourceID: 2894; TargetID: 3328),
    (SourceID: 2903; TargetID: 256),
    (SourceID: 2904; TargetID: 0),
    (SourceID: 2912; TargetID: 2816),
    (SourceID: 2917; TargetID: 256),
    (SourceID: 2923; TargetID: 2816),
    (SourceID: 2928; TargetID: 256),
    (SourceID: 2931; TargetID: 3328),
    (SourceID: 2932; TargetID: 3584),
    (SourceID: 2944; TargetID: 3584),
    (SourceID: 2949; TargetID: 2048),
    (SourceID: 2950; TargetID: 3584),
    (SourceID: 2951; TargetID: 3328),
    (SourceID: 2952; TargetID: 3328),
    (SourceID: 2954; TargetID: 3328),
    (SourceID: 2956; TargetID: 2048),
    (SourceID: 2958; TargetID: 2048),
    (SourceID: 2961; TargetID: 2048),
    (SourceID: 2962; TargetID: 3328),
    (SourceID: 2964; TargetID: 3328),
    (SourceID: 2965; TargetID: 3584),
    (SourceID: 2967; TargetID: 3328),
    (SourceID: 2969; TargetID: 3328),
    (SourceID: 2974; TargetID: 4096),
    (SourceID: 3511; TargetID: 2816),
    (SourceID: 3566; TargetID: 256)
  );

implementation

end.

