% *************************************************************************
% 
% Copyright: (c) 2011 Rohde & Schwarz GmbH & CO KG.    All rights reserved.
%                Muehldorfstr. 15
%                D-81671 Munich
%
%                8.3.2011       T. Roeder, Rohde&Schwarz
%
% *************************************************************************
% This program converts a binary '.mat' waveform file to a Rohde & Schwarz
% '.wv' waveform file that can be processed by R&S instruments.
% The program expects a '.mat' file containing a 1D I-data and a 1D Q-data 
% array named I and Q respectively. Additionally, the '.mat' file must 
% contain the clock frequency as a variable named fc.
% The output '.wv' waveform file is transferred to the remote instrument's 
% ARB.
% (Optionally, the waveform can be saved in the current directory.)
% *************************************************************************
%
%        filename     Input waveform file. The binary MATLAB file must have
%                     the extention '.mat' or '.MAT' 
%
%        InstrObj     Object for remote instrument created by rs_connect.
%        IQinfo       structure containing all necessary information for
%                     waveform file generation 
%                     IQinfo has to be of the following form:
%                     IQinfo.I_data   (mandatory)  1D array of I-data
%                     IQinfo.Q_data   (mandatory)  1D array of Q-data          
%                     IQinfo.markerlist.one        2D array marker list
%                                                  e.g.  Position / Value
%                                                           0         0
%                                                          10         1
%                                                          50         0
%                                                  => [[0 0];[10 1];[50 0]]
%                     IQinfo.markerlist.two        four marker lists are
%                     IQinfo.markerlist.three      possible
%                     IQinfo.markerlist.four
%                     IQinfo.clock    (mandatory)  desired clock rate (in Hz)
%                     IQinfo.filename              extension '.wv' is
%                                                  mandatory
%                     IQinfo.path                  instrument path
%                     IQinfo.comment               e.g "best waveform ever"
%        Playback     playback = 0, if no immediate playback on remote 
%                                   instrument is desired
%                     playback = 1, if immediate playback on remote 
%                                   instrument is desired
%        save_local   save_local = 0, if waveform shall be saved only
%                                     temporarily
%                     save_local = 1, if waveform shall be locally saved to
%                                     hard disk of your pc
%
% *************************************************************************
function Mat2wv(matfilename,tcpipAddress)

% input file
filename = matfilename;  
currentFolder = pwd;
InstrObject = 0;

% check the content of the .MAT file
s = whos ('-file', filename);

% some mandatory variables must exist
% preset flags
checkI = 0;       
checkQ = 0;
checkfc = 0;

for k=1:length(s)
    disp(['  ' s(k).name '  ' mat2str(s(k).size) '  ' s(k).class])
    if( strcmp( s(k).name, 'I' ) )
        checkI = 1;
    end
    if( strcmp( s(k).name, 'Q' ) )
        checkQ = 1;
    end
    if ( strcmp( s(k).name, 'fc' ) )
        checkfc = 1;
    end
end

if (checkI == 0) 
    disp ('*** Mandatory variable I (containing I data) is missing');
    return;
end
if (checkQ == 0) 
    disp ('*** Mandatory variable Q (containing Q data) is missing');
    return;
end
if (checkfc == 0) 
    disp ('*** Mandatory variable fc (Clock Frequency) is missing');
    return;
end
     
% load data from file
load (filename)

% new filename
wvfile = regexprep(filename, '.mat', '.wv', 'ignorecase');

% populate waveform structure
IQInfo.I_data         = I;
IQInfo.Q_data         = Q;
IQInfo.comment        = 'Waveform converted from .MAT file';
IQInfo.clock          = fc;
IQInfo.filename       = wvfile;
%IQInfo.path           = 'D:\';               % instrument path under windows              
                                             % (e.g. for SMU)
%IQInfo.path           = '/var/smbv/';       % instrument path under linux 
                                             % (e.g. for SMBV)
%IQInfo.path           = '/hdd/';            % instrument path under linux 
                                             % with hardware option
                                             % 'removable hard disk'
IQInfo.path           = '/var/user/';       % Linux based, SMW200A

%IQInfo.markerlist.one = [[0 1];[10 0]];
%IQInfo.markerlist.two = [[0 1];[100 0]];
    
% user info
disp (['Output filename: ', wvfile]) 
      
% plot I/Q data
subplot(2,1,1);
hold all
grid on
plot (IQInfo.I_data);
plot (IQInfo.Q_data);
title ('I(t), Q(t)', 'FontSize',8);
xlabel ('Samples')
ylabel ('Amplitude')
 
% plot FFT
subplot (2,1,2);
IQdata = IQInfo.I_data + 1i*IQInfo.Q_data;
Len = length(IQInfo.I_data);
Pyy = 20*log10(abs(fftshift(fft(IQdata)))/Len);
plot (Pyy);
title ('FFT', 'FontSize',8);
xlabel ('n')
ylabel ('Log Mag / dB')

if (nargin ~= 1)

    VisaDevStr = strcat('TCPIP::',tcpipAddress,'::INSTR');

    [status, InstrObject] = rs_connect( 'visa', 'rs', VisaDevStr );
    if( ~status )
        disp (['*** Return status from rs_connect() is : ' num2str(status)]);
        clear;
        return;
    end

    % query instrument
    [status, Result] = rs_send_query( InstrObject, '*IDN?' );
    if( ~status )
        disp (['*** Return status from rs_send_query() is : ' num2str(status)]);
        clear;
        return;
    end

    % test for R&S instrument
    if (isempty(strfind(Result, 'Rohde&Schwarz')))
        disp ('*** Not a Rohde&Schwarz instrument');
        clear;
        return;
    end
end

% use VISA interface from National Instruments to connect via TCP/IP


% apply some RF settings
% [status, Result] = rs_send_query( InstrObject, 'FREQ 1.0 GHz; *OPC?' );
% if( ~status )
%     disp ('*** Failed to set frequency.');
%     clear;
%     return;
% end
% [status, Result] = rs_send_query( InstrObject, 'POW -30.0 dBm; *OPC?' );
% if( ~status )
%     disp ('*** Failed to set level.');
%     clear;
%     return;
% end

% % generate and send waveform
% playback   = 1;       % start in path A
% save_local = 0;       % waveform only temporarily saved
% 
% [status] = rs_generate_wave( InstrObject, IQInfo, playback, save_local );
% 
% if( ~status )
%     disp ('*** Failed to send waveform');
%     clear;
%     return;
% end
% 
% %generate waveform (no sending of waveform)
% 
% playback   = 0;       % no start
% save_local = 1;       % save waveform to PC
% [status] = rs_generate_wave (InstrObject, IQInfo, playback, save_local);

% generate and send waveform
playback   = 1;       % start in path A
save_local = 1;       % save waveform to PC

[status] = rs_generate_wave( InstrObject, IQInfo, playback, save_local );

if( ~status )
    disp ('*** Failed to send waveform');
    clear;
    return;
end

% % delete instrument object
% delete( InstrObject );
disp('wv save file path');
disp(currentFolder);

clear;

return;


