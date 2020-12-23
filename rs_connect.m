% function rs_connect
% *************************************************************************
% 
% Copyright: (c) 2011 Rohde & Schwarz GmbH & CO KG.    All rights reserved.
%                Muehldorfstr. 15
%                D-81671 Munich
%
% *************************************************************************
% This function returns an object for the remote instrument by means of the
% configuration information given by the user. Missing information is
% filled up with default values.
%%
% @param interface                        interface type (gpib, visa, tcpip)
%   if interface is gpib:
%     @param ParamStruct.GPIB.vendor      vendor type (e.g. ni, agilent,rs)
%     @param ParamStruct.GPIB.board       board number
%     @param ParamStruct.GPIB.primaddr    primary address
%     @param ParamStruct.GPIB.secaddr     secondary address (optional)
% if interface is visa:
%     @param ParamStruct.VISA.vendor      vendor type (e.g. ni, tek, agilent,rs)
%     @param ParamStruct.VISA.rsc         VISA resource string
% if interface is tcpip:
%     @param ParamStruct.TCPIP.rsc        hostname of remote instrument
%%
% @return Status                      Status = 0, if object could not be created.
%                                     Status = 1, if object was created successfully.
% @return InstrObj                    The object which was created for the newly
%                                     connected remote instrument.        
%**************************************************************************

function [Status,InstrObj] = rs_connect( varargin )  

    Status   = 0;
    InstrObj = 0;

    % check if the instrument control toolbox is there
    InstrControlInstalled = license( 'checkout', 'instr_control_toolbox' );
    if( InstrControlInstalled==0 )
        disp('MATLAB Instrument Control Toolbox is not available.');
        return;
    end

    % preset default values
    ParamStruct.interface     = 'visa';
    ParamStruct.GPIB.vendor   = 'ni';
    ParamStruct.GPIB.board    = 0;
    ParamStruct.GPIB.primaddr = 28;
    ParamStruct.GPIB.secaddr  = -1;
    ParamStruct.VISA.vendor   = 'ni';
    ParamStruct.VISA.rsc      = '';
    ParamStruct.TCPIP.rsc     = '';

    % no arguments provided
    if (nargin<1)
        disp ('*** Not enough input prameters to rs_connect()');
        return;
    end

    % check if first argument is a string
    if (ischar(varargin{1}) ~=1)
        disp ('*** First parameter must be a string defining the interface type (''gpib'' ''visa'' or ''tcpip'').');
        return;
    end
    
    % get current info on supported instruments / interfaces
    HwInf = instrhwinfo();

    % determine interface type
    switch( upper( varargin{1} ) )
        case 'GPIB' 
            ParamStruct.interface = 'gpib';
        case 'VISA' 
            ParamStruct.interface = 'visa';
        case 'TCPIP' 
            ParamStruct.interface = 'tcpip';
        otherwise
            disp ('*** Interface type must either be ''gpib'', ''visa'', or ''tcpip''.');
            return;
    end
    
    % verify that the desired interface is supported
    if( ~strcmp( ParamStruct.interface, HwInf.SupportedInterfaces ) )
        disp ( [ 'Your selected interface  : ' ParamStruct.interface ] );
        disp (   '*** Interface type is not supported');
        return;
    end

    % evaluate parameters of GPIB based interface
    if (isequal(ParamStruct.interface,'gpib'))
        % vendor
        if (nargin > 1)
            switch(lower(varargin{2}))
                case 'advantech'
                    ParamStruct.GPIB.vendor = 'advantech';
                case 'agilent'
                    ParamStruct.GPIB.vendor = 'agilent';
                case 'cec'
                    ParamStruct.GPIB.vendor = 'cec';
                case 'contec'
                    ParamStruct.GPIB.vendor = 'contec';
                case 'ics'
                    ParamStruct.GPIB.vendor = 'ics';
                case 'iotech'
                    ParamStruct.GPIB.vendor = 'iotech';
                case 'keithley'
                    ParamStruct.GPIB.vendor = 'keithley';
                case 'mcc'
                    ParamStruct.GPIB.vendor = 'mcc';
                case 'ni'
                    ParamStruct.GPIB.vendor = 'ni';
                case 'rs'
                    ParamStruct.GPIB.vendor = 'rs';
                otherwise
                    disp ('*** GPIB interface type not supported');
                    return;
            end
        end
        % board number (range 0...7)
        if (nargin > 2)
            if (~isnumeric(varargin{3}))
                disp ('*** GPIB board number must be numeric.');
                return;
            end
            ParamStruct.GPIB.board = varargin{3};
            if (ParamStruct.GPIB.board < 0 || ParamStruct.GPIB.board > 7)
                disp ('*** GPIB board number is out of range. Use 0...7.');
                return;
            end
        end
        % set primary address of instrument (range 0...30)
        if (nargin > 3)
            if (~isnumeric(varargin{4}))
                error('*** GPIB primary address number must be numeric.');
            end
            ParamStruct.GPIB.primaddr = varargin{4};
            if (ParamStruct.GPIB.primaddr < 0 || ParamStruct.GPIB.primaddr > 30)
                disp ('*** GPIB primary address is out of range. Use 0...30.');
                return;
            end
        end
        % set secondary address of instrument (range 96...126)
        if (nargin > 4)
            if (~isnumeric(varargin{5}))
                disp ('*** GPIB secondary address number must be numeric.');
                return;
            end
            ParamStruct.GPIB.secaddr = varargin{5};
            if (ParamStruct.GPIB.secaddr < 96)
                disp ('*** GPIB secondary address is out of range. Minimum value is 96.');
                return;
            end
            if (ParamStruct.GPIB.secaddr > 126)
                disp ('*** GPIB secondary address is out of range. Maximum value is 126.');
                return;
            end
        end
        
        disp(['Interface      : ' ParamStruct.interface]);
        disp(['Vendor         : ' ParamStruct.GPIB.vendor]);
        disp(['Board No       : ' num2str(ParamStruct.GPIB.board)]);
        disp(['Primary addr   : ' num2str(ParamStruct.GPIB.primaddr)]);
        if (ParamStruct.GPIB.secaddr < 0)
            disp('Secondary addr : not used');
        else
            disp(['Secondary addr : ' num2str(ParamStruct.GPIB.secaddr)]);    
        end
        
        % verify that the desired vendor is supported
        HwInf = instrhwinfo(ParamStruct.interface);
        if (isempty(strcmp(ParamStruct.GPIB.vendor, HwInf.InstalledAdaptors)))
            x = '';
            for N=1:length(HwInf.InstalledAdaptors)
                x = [HwInf.InstalledAdaptors{1,N} ' ' x];
            end
            disp(['Supported vendors are : ' x]);
            disp(['Your selected vendor  : ' ParamStruct.GPIB.vendor]);
            disp( '*** Vendor is not supported by your driver/Matlab installation.');
            return;
        end

       % build GPIB object and set Status variable
       [InstrObj, Status] = build_GPIB_object(ParamStruct);
    end
    
    % evaluate VISA resource string
    if( isequal( ParamStruct.interface, 'visa' ) )
        
        % vendor
        if( nargin > 1 )
            switch( lower( varargin{2} ) )
                case 'agilent'
                    ParamStruct.VISA.vendor = 'agilent';
                case 'tek'
                    ParamStruct.VISA.vendor = 'tek';
                case 'ni'
                    ParamStruct.GPIB.vendor = 'ni';
                case 'rs'
                    ParamStruct.GPIB.vendor = 'rs';
                otherwise
                    disp ('*** VISA vendor not supported');
                    return;
            end
        end
        
        % resource string
        if (~ischar(varargin{3}))
            disp ('*** VISA resource string is not a string');
            return;
        end
        ParamStruct.VISA.rsc = varargin{3};
        
        % verify that the desired vendor is supported
        HwInf = instrhwinfo(ParamStruct.interface);
        if (isempty(strcmp(ParamStruct.VISA.vendor, HwInf.InstalledAdaptors)))
           x = '';
            for N=1:length(HwInf.InstalledAdaptors)
                x = [HwInf.InstalledAdaptors{1,N} ' ' x];
            end
            disp (['Supported vendors are : ' x]);
            disp (['Your selected vendor  : ' ParamStruct.VISA.vendor]);
            disp ( '*** Vendor is not supported by your driver/Matlab installation.');
            return;
        end

        % build VISA object
        [InstrObj, Status] = build_VISA_object(ParamStruct);
    end
       
    
    % evaluate TCPIP resource string
    if (isequal(ParamStruct.interface,'tcpip'))
         disp(['Interface      : ' ParamStruct.interface]);
         
         % hostname
        if (~ischar(varargin{2}))
            disp ('*** hostname must be a string');
            return;
        end
        ParamStruct.TCPIP.rsc = varargin{2};
        disp(['Hostname       : ' ParamStruct.TCPIP.rsc]);
        
       
        % build TCPIP object 
        [InstrObj, Status] = build_TCPIP_object(ParamStruct);
        
        %increase InputBufferSize
        %set(InstrObj, 'InputBufferSize', 30000);
    end
    
    
    %set Status variable
    if (Status < 1)
        disp ('*** VISA, GPIB or TCPIP object was not created.');
        return;
    end

    % set buffer sizes to 8 kBytes
    InstrObj.OutputBufferSize = 8*1024;
    InstrObj.InputBufferSize  = 8*1024;
return;
    
% end of function rs_connect

%
% function - build a GPIB object
%
function [InstrObj, Status] = build_GPIB_object(ParamStruct)
    
    InstrObj = 0;
    Status = 0;
    
    % do we use a secondary address number ?
    if (ParamStruct.GPIB.secaddr >= 0)
        try
            % try to create GPIB object
            InstrObj = gpib (ParamStruct.GPIB.vendor, ParamStruct.GPIB.board, ParamStruct.GPIB.primaddr, 'SECOND', ParamStruct.GPIB.secaddr);
        catch err
            disp ('*** Call to gpib() failed.');
            disp (['*** Matlab error message : ' err.message]);
            return;
        end
        
        % try to open
        try
            fopen (InstrObj);
        catch err
            disp (['*** Cannot open instrument connection. Return status is : ''' InstrObj.Status '''']);
            disp (['*** Matlab error message : ' err.message]);
            return;
        end
        
        fclose(InstrObj);
        
    else

        try
            InstrObj = gpib(ParamStruct.GPIB.vendor, ParamStruct.GPIB.board, ParamStruct.GPIB.primaddr);
        catch err
            disp ('*** Call to gpib() failed.');
            disp (['*** Matlab error message : ' err.message]);
            return;
        end
        
        % try to open
        try
            fopen (InstrObj);
        catch err
            disp (['*** Cannot open instrument connection. Return status is : ''' InstrObj.Status '''']);
            disp (['*** Matlab error message : ' err.message]);
            return;
        end
        
        fclose(InstrObj);
    end
    Status = 1;
return;
    
%
% function - build a VISA object
%
function [InstrObj, Status] = build_VISA_object (ParamStruct)
    
    InstrObj = 0;
    Status = 0;
    
    disp( [ 'VISA resource string : ' ParamStruct.VISA.rsc ] );
    
    try
        InstrObj = visa( ParamStruct.VISA.vendor, ParamStruct.VISA.rsc );             
    catch err
        disp ('*** Call to visa() failed.');
        disp (['*** Matlab error message : ' err.message]);
        return;
    end

    disp( [ 'VISA interface type : ' InstrObj.type ] );

    % try to open
    try
        fopen( InstrObj );
    catch err
        disp (['*** Cannot open instrument connection. Status is ''' InstrObj.Status '''']);
        disp (['*** Matlab error message : ' err.message]);
        return;
    end
        
    fclose(InstrObj);
    Status = 1;
return;

%
% function - build a TCPIP object
%
function [InstrObj, Status] = build_TCPIP_object (ParamStruct)
    
    InstrObj = 0;
    Status = 0;
    
    try
        InstrObj = tcpip (ParamStruct.TCPIP.rsc,5025); 
    catch err
        disp ('*** Call to tcpip() failed.');
        disp (['*** Matlab error message : ' err.message]);
        return;
    end

    % try to open
    try
        fopen (InstrObj);
    catch err
        disp (['*** Cannot open instrument connection. Status is ''' InstrObj.Status '''']);
        disp (['*** Matlab error message : ' err.message]);
        return;
    end
        
    fclose(InstrObj);
    Status = 1;
return;

% end of file
