function one_box_deb_transientT_driver(ModelPar)
%ModelPar.Ms: C protection equivalent of mineral surface, 500, 1000, 2000
%ModelPar.Tref: reference temperature, 290 or 280 K
%ModelPar.Emc: activation energy for enzyme and doc adsoprtion to soil minerals
%ModelPar.Esc: activation energy for enzyme depolymerization and doc uptake
%ModelPar.Yld_x: assimilation efficiency of monomer into reserve
%ModelPar.opt=1[0]: plastic [rigid] microbe
%clc;
global vid;
global par;

[~,results]=system('pwd');
sstrs=strsplit(results,'/one_bug_model');

matfldir=[sstrs{1},'/one_bug_model/mat_files/transtT'];

system(['mkdir -p ', matfldir]);

%define vid
vid.som=1;
vid.doc=2;
vid.micc=3;
vid.micb=4;
vid.ee=5;
vid.co2=6;
vid.mss=7;
vid.fdoc=8; %doc uptake, diagnostic variable
vid.cout=9; %microbial output, diagnostic variable

Ms=ModelPar.Ms;
Tref=ModelPar.Tref;
Ems=ModelPar.Ems;
Esc=ModelPar.Esc;
Yld_x=ModelPar.Yld_x;
opt=ModelPar.opt;


par=set_par_default();
par=par_scal(par,opt);

npp=ModelPar.npp/365;    %gC /day
frc_soc=.8;
par.input_som=npp.*frc_soc;
par.input_doc=npp.*(1-frc_soc);

iofile=[matfldir,'one_box_deb_trantT_Ms',num2str(Ms),'_',ModelPar.name,...
    'Tref',num2str(Tref),...
    '_Ems',num2str(Ems),'_Esc',num2str(Esc),'_Yld',num2str(Yld_x),...
    '_opt',num2str(opt),'.mat'];

par.M1=Ms;%1000,2000
par.Yld_micc=Yld_x;

%do spin up for 4000 years

[doc,micb,micc,ee,som,~,~]=one_box_ss(par);

%define initial conditions
x0(vid.som)=som;
x0(vid.doc)=doc;
x0(vid.micc)=micc;
x0(vid.micb)=micb;
x0(vid.ee)=ee;
x0(vid.co2)=0;
x0(vid.mss)=par.M1;
x0(vid.fdoc)=0;
x0(vid.cout)=0;
%define the solver

xpar=[249.544170969785   5341.422691388677   5.617549086429];
rgas=8.31446;                      %universal gas constant, [J/K/mol]
TEa=set_Ea_default();

TEa.Ea_vesom = Esc/rgas;
TEa.Ea_vbdoc = Esc/rgas;    
    
TEa.Ea_kmdoc = Ems/rgas;             %doc adsorption to mineral    [K]
TEa.Ea_kmee  = Ems/rgas;             %enzyme adsorption to mineral [K]

par0=par;

T_fact0=fact_murphy(Tref,xpar);
Tfrz=ModelPar.Tfrz;  %basal temperature for the diurnal cycle


%do transient run 120 years
dt=1/24;
tend=365*ModelPar.years;


%introduce the temperature effect of mineral adsorption

A1=10;         %seasonal amplitude
A2=4;          %daily amplitude
w1=2.*pi/365;
w2=2.*pi;
kend=tend/dt;

TOUT_ctl=zeros(kend+1,1);
YOUT_ctl=zeros(kend+1,9);
YOUT_ctl(1,:)=x0;
TOUT_ctl(1,:)=0;
TEMP=zeros(kend,1);
for kk = 1 : kend
    t=(kk-0.5)*dt;
    temp=Tfrz+A1.*sin(w1.*t-pi/2)+A2.*sin(w2.*t);
    TEMP(kk)=temp;
    T_fact=fact_murphy(temp,xpar);
    fref=T_fact./T_fact0.*(temp./Tref);
    Tinv=1./temp-1./Tref;
    
    par=par_scal_temp(par0, TEa, fref, Tinv);
    
    YOUT_ctl(kk+1,:)=adptmbbks1(@one_box_deb,YOUT_ctl(kk,:),TOUT_ctl(kk),dt);
    TOUT_ctl(kk+1)=TOUT_ctl(kk)+dt;
end

%plot(TEMP,diff(YOUT11(:,vid.co2))./dt,'.');
%hold on;
%plot(TEMP,diff(YOUT12(:,vid.co2))./dt,'r.');
%legend('Microbe+Mineral','Microbe only');
%set(gca,'FontSize',14);
%grid on;
%ylabel('g C day^-^1','FontSize',14);
%xlabel('Temperature (K)','FontSize',14);
lag=(365-ordinalday('15-July-2019'))/dt;
xf_last=YOUT_ctl(kk+1,:);
xf_middle=YOUT_ctl(kk+1-lag,:);
lag=(365-ordinalday('1-Oct-2019'))/dt;
xf_down=YOUT_ctl(kk+1-lag,:);
lag=(365-ordinalday('1-Mar-2019'))/dt;
xf_upper=YOUT_ctl(kk+1-lag,:);
save(iofile,'YOUT_ctl','TOUT_ctl','TEMP','vid','ModelPar','xf_last',...
    'xf_middle','xf_upper','xf_down');
end
