
%function Mat2wv(matfilename,tcpipAddress,visaVendor)
%Change the .mat file to .wv file
%matfilename, filename.mat
%tcpipAddress,TCPIP Address of remote signal generator
%visaVendor,the name of visa driver venfor, 'rs','ni','keysight,'tek'

function Mat2wv(matfilename,tcpipAddress,visaVendor)

% input file
filename = matfilename;  
currentFolder = pwd;
InstrObject = 0;

% check the content of the .MAT file
s = whos ('-file', filename);

% some mandatory variables must exist,check I,Q and fc varaible
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
load(filename);

% new filename
wvfile = regexprep(filename, '.mat', '.wv', 'ignorecase');

% populate waveform structure
IQInfo.I_data         = I;
IQInfo.Q_data         = Q;
IQInfo.comment        = 'Waveform converted from .MAT file';
IQInfo.clock          = fc;
IQInfo.filename       = wvfile;
IQInfo.path           = '/var/user/';       % Linux based, SMW200A
    
% user info
disp (['Output filename: ', wvfile]) 

if (nargin == 3)

    VisaDevStr = strcat('TCPIP::',tcpipAddress,'::INSTR');

    [status, InstrObject] = rs_connect( 'visa', visaVendor, VisaDevStr );
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
    
elseif(nargin == 2) 

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

% generate and send waveform
playback   = 1;       % start in path A
save_local = 1;       % save waveform to PC

[status] = rs_generate_wave( InstrObject, IQInfo, playback, save_local );

if( ~status )
    disp ('*** Failed to send waveform');
    clear;
    return;
end



% delete instrument object
%delete( InstrObject );
disp('wv save file path');
disp(currentFolder);

return;


