%function ChirpUpPulse(fsample,fmdev,ton,toff)
%This function generate IQ Date for Chirp Pulse signal
%fsample is Sampling frequency, unit in Hz,KHz,MHZ,GHz
%fmDev is chirp modulation frequency deviation, unit in Hz,KHz,MHZ,GHz
%ton is Pulse on period, unit in s,ms,ns,ps
%toff is Pulse off period, unit in s,ms,ns,ps
function [ status ] = ChirpUpPulse(fsample,fmdev,ton,toff)

status = 0;


% *************************************************************************
% Create Signal
% *************************************************************************

% set the waveform parameters
Fsample       = UnitFreq(fsample);         % Sampling frequecy
FmDev         = UnitFreq(fmdev);             % FM deviation (-f/2 ... +f/2) 
Ton           = UnitTime(ton);               % Pulse on period
Toff          = UnitTime(toff);              % Pulse off period
Ttotal        = Ton + Toff;                  % Pulse period
LocalFileName = strcat(TimeUnit(Ton),'_',TimeUnit(Ttotal),'_','BW',...
    FreqUnit(FmDev),'_','UpChirp','_',datestr(now,30),'.mat');   
% The local and remote file name


Tsample = 1/Fsample;                        % resulting sample time
Points  = round( Ton / Tsample );          % resulting number of waveform points
k = 0:1:Points-1;                           % point count

am = ones( 1, Points );                     % amplitude is 1
fm = -FmDev/2:FmDev/(Points-1):+FmDev/2;    % frequency versus time
phase = 2.0 * pi / Fsample * cumsum(fm);

I_data_on = 0.707 * am .* cos( phase );
Q_data_on = 0.707 * am .* sin( phase );

% Blank time
I_data_off = zeros(1,round(Toff/Tsample));
Q_data_off = zeros(1,round(Toff/Tsample));

% Combin
I = [I_data_on I_data_off];
Q = [Q_data_on Q_data_off];
fc = Fsample;   

% *************************************************************************
% Plot Data
% *************************************************************************
rs_visualize( Fsample, I, Q);

% *************************************************************************
% Save Data
% *************************************************************************
save(LocalFileName,'I','Q','fc');

% check for R&S device, we also need the *IDN? result later...
disp( 'Genarate waveform...' );
Mat2wv(LocalFileName);

disp( 'Complete...' );

return;


