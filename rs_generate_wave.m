% function rs_generate_wave
% *************************************************************************
% 
% Copyright: (c) 2011 Rohde & Schwarz GmbH & CO KG.    All rights reserved.
%                Muehldorfstr. 15
%                D-81671 Munich
%
% *************************************************************************
% This function takes a 1D I-data and a 1D Q-data array, combines them and
% generates a file equipped with all mandatory and optional tags as
% specified in the manual. This file is transfered to the remote instrument
% where it can be played immediately.
%%
% @param InstrObj     Object for remote instrument created by rs_connect.
% @param IQinfo       struct containing all necessary information
%                     IQinfo has to be of the following form:
%                     IQinfo.I_data   (mandatory)  1D array with I-data
%                     IQinfo.Q_data   (mandatory)  1D array with Q-data          
%                     IQinfo.clock    (mandatory)  ARB clock rate (Hz)
%                     IQinfo.markerlist.one        2D array marker list
%                                                  e.g.  Position / Value
%                                                           0         0
%                                                          10         1
%                                                          50         0
%                                                  => [[0 0];[10 1];[50 0]]
%                     IQinfo.markerlist.two        four marker lists are
%                     IQinfo.markerlist.three      possible
%                     IQinfo.markerlist.four
%                     IQinfo.path                  storage path on the instrument 
%                     IQinfo.filename              filename on instrument
%                                                  extension '.wv' is mandatory
%                     IQinfo.comment               optional comment
%                     IQinfo.no_scaling = 0        waveform is automatically 
%                                                  scaled and the peak and 
%                                                  average value calculated
%                                       = 1        no scaling, peak and rms
%                                                  offsets are set to zero
% @param StartPlayback  StartPlayback = 0    no automatic ARB activation
%                       StartPlayBack = 1    start ARB in path A
%                       StartPlayback = 2    start ARB in path B
% @param KeepLocalFile  KeepLocalFile = 0    remove thelocal file after
%                                            transfer
%                       KeepLocalFile = 1    keep the local file
%%
% @return Status      Status = 0, if file generation or transmission fails
%                     Status = 1, if generation and transmission succeeds
% *************************************************************************

function [Status] = rs_generate_wave( InstrObj, IQinfo_user, ...
                        StartPlayback, KeepLocalFile )

    Status = 0;

    % set defaults for non mandatory fields
    IQinfo.path       = 'D:\';
    IQinfo.filename   = 'untitled.wv';             
    IQinfo.comment    = '';
    IQinfo.copyright  = '';
    IQinfo.no_scaling = 0;

    % check number of arguments
    if (nargin ~= 4)
        disp ('*** Incorrect number of input arguments.')
        return;
    end

    % check the presence of the mandatory entries
    if ((isfield(IQinfo_user,'I_data')) && (isfield(IQinfo_user,'Q_data')) ...
            && (isfield(IQinfo_user,'clock')) == 1)
        IQinfo.I_data = single(IQinfo_user.I_data);
        IQinfo.Q_data = single(IQinfo_user.Q_data);
        IQinfo.clock  = IQinfo_user.clock;
    else 
        disp ('*** Mandatory data field (I-data, Q-data or clock) is missing');
        return;
    end

    % check if path information is a string
    if (isfield(IQinfo_user,'path'))
        if (ischar(IQinfo_user.path))
            IQinfo.path = IQinfo_user.path;
        else
            disp ('*** IQinfo.path needs to be a string');
            return;
        end
    end

    % check if filename is a string and check the correct extension
    if (isfield(IQinfo_user,'filename'))
        if (ischar(IQinfo_user.filename))
            if (strcmpi(IQinfo_user.filename(end-2:end),'.wv')==1)
                IQinfo.filename = IQinfo_user.filename;
            else
                disp ('*** File extension must be .wv.');
                return;
            end
        else
            disp ('*** IQinfo.filename needs to be a string.');
            return
        end
    end 

    % check if comment is a string
    if (isfield(IQinfo_user,'comment'))
        if (ischar(IQinfo_user.comment))
            IQinfo.comment = IQinfo_user.comment;
        else
            disp ('*** IQinfo.comment needs to be a string');
            return;
        end
    end

    % check if copyright is a string
    if (isfield(IQinfo_user,'copyright'))
        if (ischar(IQinfo_user.copyright))
            IQinfo.copyright = IQinfo_user.copyright;
        else
            disp ('*** IQinfo.copyright needs to be a string');
            return;
        end
    end

    % check optional marker lists
    if (isfield(IQinfo_user,'markerlist'))
        if (isfield(IQinfo_user.markerlist,'one'))
            if (check_marker_array(IQinfo_user.markerlist.one))
                IQinfo.markerlist.one = build_marker_string(IQinfo_user.markerlist.one);
            else
                disp ('*** Error in marker list 1');
                return;
            end
        end
        if (isfield(IQinfo_user.markerlist,'two'))
            if (check_marker_array(IQinfo_user.markerlist.two))
                IQinfo.markerlist.two = build_marker_string(IQinfo_user.markerlist.two);
            else
                disp ('*** Error in marker list 2');
                return;
            end
        end
        if (isfield(IQinfo_user.markerlist,'three'))
            if (check_marker_array(IQinfo_user.markerlist.three))
                IQinfo.markerlist.three = build_marker_string(IQinfo_user.markerlist.three);
            else
                disp ('*** Error in marker list 3');
                return;
            end
        end
        if (isfield(IQinfo_user.markerlist,'four'))
            if (check_marker_array(IQinfo_user.markerlist.four))
                IQinfo.markerlist.four = build_marker_string(IQinfo_user.markerlist.four);
            else
                disp ('*** Error in marker list 4');
                return;
            end
        end
    end

    % check if optional no_scaling field is there
    if (isfield(IQinfo_user,'no_scaling'))
        if (isscalar(IQinfo_user.no_scaling))
            IQinfo.no_scaling = IQinfo_user.no_scaling;
        else
            disp ('*** IQinfo.no_scaling neeeds to be a scalar value');
            return;
        end
    end

    % check I and Q data for correct length (>1 number)
    if ((length(IQinfo.I_data) ~= 1) && (length(IQinfo.Q_data) ~= 1)) 
        if length(IQinfo.I_data) ~= length(IQinfo.Q_data)
            disp ('*** I and Q data array needs to be of the same length.');
            return;
        end
    end

    % get data length
    IQ_data_len = length(IQinfo.I_data);

    % prepare IQ data array, format is IQIQIQ...
    try
        IQ_data = single(zeros(1, 2*IQ_data_len));  
        IQ_data(1:2:end) = single(IQinfo.I_data);
        clear IQinfo.I_data;
        IQ_data(2:2:end) = single(IQinfo.Q_data);
		clear IQinfo.Q_data;
    catch err
        disp ('*** Failed to assemble data structure.');
        disp (['*** Matlab error message : ' err.message]);
        return;
    end

    if (~IQinfo.no_scaling)
         % normalize all I/Q data to a peak vector length of 1.0
         % -> this ensures that no clipping occurs and that the 16 bits are
         %    used as good as possible
        max_IQ_data = max(abs(IQinfo.I_data + 1i*IQinfo.Q_data));
        IQ_data = IQ_data / max_IQ_data;
        disp('  ');
        disp(['Maximum envelope value is ',num2str(max_IQ_data,5),', waveform normalized to 1.0 max.']);
  		peak = 1.0;
        max_IQ_data = 1.0;
        % compute peak, rms and crest factor 
        rms  = sqrt(mean(IQ_data(1:2:end).*IQ_data(1:2:end) + IQ_data(2:2:end).*IQ_data(2:2:end))) / max_IQ_data;
        crf  = 20*log10(peak/rms);
    else
        % in case of no scaling we need to check for clipping
        if (max(IQinfo.I_data)>1.0 || min(IQinfo.I_data)<-1.0)
            disp ('*** IQinfo.I_data must be in the range between -1 to +1 if auto scaling is disabled.');
            disp(['*** Current range is ', num2str(min(IQinfo.I_data)), ' - ', num2str(max(IQinfo.I_data))]);
            return;
        end
        if (max(IQinfo.Q_data)>1.0 || min(IQinfo.Q_data)<-1.0)
            disp ('*** IQinfo.Q_data must be in the range between -1 to +1 if auto scaling is disabled.');
            disp(['*** Current range is ', num2str(min(IQinfo.Q_data)), ' - ', num2str(max(IQinfo.Q_data))]);
            return;
        end
        if (max(abs(IQinfo.I_data + 1i*IQinfo.Q_data))>1.0)
            disp ('*** I/Q vector length must be < 1 if auto scaling is disabled.');
            return;
        end

        peak = 1.0;
        rms  = 1.0;
        crf  = 0.0;     % peak to average ration forced to zero 
    end


    disp( ' ' );
    disp( 'Waveform Parameters' );
    disp(['  Samples    : ',num2str(IQ_data_len)]);
    disp(['  Clock Freq : ',num2str(IQinfo.clock), ' Hz']);
    disp(['  Peak Level : ',num2str(peak,5)]);
    disp(['  RMS Level  : ',num2str(rms,5)]);
    disp(['  Pk/Av      : ',num2str(crf,5)]);
    disp(['  Local File : ',IQinfo.filename]);
    if (IQinfo.no_scaling)
        disp('  Scaling    : No' );
    else
        disp('  Scaling    : Auto');
    end
    disp( ' ' );
        
    % range is 16 bits for the analog outputs
    % +1.0 ---> +32767
    %  0.0 --->      0
    % -1.0 ---> -32767
    IQ_data = floor((IQ_data*32767+0.5)); 
    len     = num2str(length(IQ_data)*2 + 1);

    % open file for write (binary mode)
    WV_file_id = fopen(IQinfo.filename,'wb');
    if (WV_file_id < 0)
        disp ('Cannot open local output file.');
        return;
    end
    
    disp (['Creating local output file ''' IQinfo.filename '''...']);
    
    % The header tag must always be the very first one in the file.
    % Use 'SMU-WV' for SMU,SMJ,SMATE,AMU,AFQ,SMBV
    % No checksum is used
    fprintf (WV_file_id, '%s','{TYPE: SMU-WV, 0}' ); 

    % The comment and copyright tags are optional and only added
    % if these fields exist
    if (~(isequal(IQinfo.comment,'')))
        fprintf (WV_file_id, '%s','{COMMENT: ',IQinfo.comment,'}' );
    end
    if (~(isequal(IQinfo.copyright,'')))
        fprintf (WV_file_id, '%s','{COPYRIGHT: ',IQinfo.copyright,'}' );
    end

    % This is a field that the instrument does not evaluate
    fprintf (WV_file_id, '%s','{ORIGIN INFO: RS Matlab Toolkit}' );

    % The level offset tag for RMS and Peak offset in dB related to full scale.
    % The full scale is 1.0 for the envelope (IQ vector length).
    fprintf (WV_file_id, '%s','{LEVEL OFFS: ',num2str(20*log10(1.0/rms)),', ',num2str(20*log10(1.0/peak)),'}' );

    % The time stamp tag is optional but it is a good idea to have it in
    szDate    = datestr(date,29);
    szTime    = datestr(clock,13);
    date_time = ['{DATE: ' szDate ';' szTime '}'];
    fprintf (WV_file_id, '%s', date_time);

    % The clock rate and samples tag are mandatory.
    fprintf (WV_file_id, '%s','{CLOCK: ', num2str(IQinfo.clock),'}' ); 
    fprintf (WV_file_id, '%s','{SAMPLES: ', num2str(IQ_data_len),'}' );

    % The marker list is optional.
    if (isfield(IQinfo,'markerlist'))

        % Use the data leength also as the length of the marker information. 
        % This ensures that the markers remain in sync with the data.
        % Not mandatory but required to stay synchronized.
        fprintf (WV_file_id, '%s','{CONTROL LENGTH: ',num2str(IQ_data_len),'}');

        %fprintf (WV_file_id, '%s','{CLOCK MARKER: ', num2str(IQinfo.clock),'}' ); 
        if (isfield(IQinfo.markerlist,'one'))
            fprintf (WV_file_id, '%s','{MARKER LIST 1: ',IQinfo.markerlist.one,'}' );
        end
        if (isfield(IQinfo.markerlist,'two'))
            fprintf (WV_file_id, '%s','{MARKER LIST 2: ',IQinfo.markerlist.two,'}' );
        end
        if (isfield(IQinfo.markerlist,'three'))
            fprintf (WV_file_id, '%s','{MARKER LIST 3: ',IQinfo.markerlist.three,'}' );
        end
        if (isfield(IQinfo.markerlist,'four'))
            fprintf (WV_file_id, '%s','{MARKER LIST 4: ',IQinfo.markerlist.four,'}' );
        end
    end

    % write waveform tag
    fprintf (WV_file_id, '%s','{WAVEFORM-',len,': #' );
    fwrite (WV_file_id, IQ_data, 'int16');
    fprintf (WV_file_id, '%s','}' ); 

    % close waveform output file
    fclose  (WV_file_id);
    
    % free memory
    clear IQ_data;

    % ------------------------------------------------------------------------
    %
    % Transfer waveform file to instrument
    %
    % ------------------------------------------------------------------------

    % check if the fist argument is an object (instrument)
    if (isobject(InstrObj) ~= 1)
        disp ('*** No instrument object specified. Waveform saved locally.');
        Status = 1;
        return;
    end

    if ( ~strcmp(InstrObj.Status, 'open') )
        disp ('Opening instrument connection...');

        % open the instrument connection
        try
            fopen (InstrObj);
        catch err
            disp ('*** Cannot open instrument connection.');
            disp (['*** Matlab error message : ' err.message]);
            return;
        end
    end
    
    disp ('Clearing instrument error queue...');
    
    stat = read_error_queue (InstrObj);
    if (stat < 1)
        fclose(InstrObj);
        disp ('*** Cannot read error queue.');
        return;
    end

    disp ('Sending local waveform file to instrument...');

    % determine input file size
    filedata = dir(IQinfo.filename);
    filesize = filedata.bytes;
    
    disp (['  File size is ', num2str(filesize) , ' bytes']);
   
    % set a block size for reading from the file and sending
    % to the instrument
    BlockSize = 1024*1024;
    if (BlockSize > InstrObj.OutputBufferSize)
		BlockSize = InstrObj.OutputBufferSize;
    end
    
    disp(['  TX bock size is ', num2str(BlockSize), ' bytes']);
    
    % create command for data upload
    cLength = strcat(num2str(length(num2str(filesize))),num2str(filesize));
    samples = sprintf('#%s',cLength);
    command = sprintf(':MMEM:DATA ''%s%s'',%s',IQinfo.path, IQinfo.filename, samples);
    
    % for GPIB connections require EOI
    if( strcmp(get(InstrObj,'Type'),'gpib')==1 || strcmp(get(InstrObj,'Type'),'visa-gpib')==1 )
        [stat, Result] = rs_send_query (InstrObj, ':SYST:COMM:GPIB:LTER EOI; *OPC?');
        if( stat < 1 || Result(1) ~= '1' )
            disp ('*** Cannot set instrument LTER mode.');
            return;
        end
    end
      
	% do not assert EOI line after transfer
    if (strcmp(get(InstrObj,'Type'),'tcpip')==0)
        EoiStat = InstrObj.EOIMode;
        InstrObj.EOIMode = 'off';
    end
    
    % open binary file for read
    WV_file_id = fopen(IQinfo.filename, 'rb');
    if (WV_file_id < 0)
        fclose(InstrObj);
        disp ('*** Cannot open local waveform file.');
        return;
    end

    % send the command part of the waveform SCPI command
    try
        fwrite (InstrObj, command, 'uchar');
    catch err
        disp (['*** Cannot send command (' command ').']);
        disp (['*** Matlab error message : ' err.message]);
        fclose (InstrObj);
        fclose(WV_file_id);
        return;
    end
    
    % display a progress bar
    bar = waitbar( 0, 'Sending Data...' );

    % the number of bytes remaining is initially set to the total
    % number of bytes to send
	Blocks = 0;
    remaining = filesize;
    while( remaining > 0 )
    
        % the next chunk is max. 1 MBytes in size
        nextblock = remaining;
        if(nextblock > BlockSize)
            nextblock = BlockSize;
        end

        % set the new number of bytes remaining
        remaining = remaining - nextblock;
        Blocks = Blocks + 1;
        
        % read the next block
        try
            [rawdata, leng] = fread (WV_file_id, nextblock, 'uchar');
        catch err
            close( bar );
            fclose (WV_file_id);
            fclose (InstrObj);
            disp ('*** Failed to read local waveform file to memory.');
            disp (['*** Matlab error message : ' err.message]);
            return;
        end

        % last block to send 
        if (remaining==0)
            % enable EOI again to terminate transfer 
            if (strcmp(get(InstrObj,'Type'),'tcpip')==0)
                InstrObj.EOIMode = 'on';
            end
        end
        
        % calculate state
        Progr = (1.0-remaining/filesize);
        waitbar( Progr, bar );
        
        % write binary data to instrument 
        try
            fwrite (InstrObj, rawdata, 'uchar');
        catch err
            close( bar );
            disp ('*** Failed to send binary data');
            disp (['*** Matlab error message : ' err.message]);
            fclose (WV_file_id);
            fclose (InstrObj);
            return;
        end
        
    end
    
    close( bar );

     % close file
    fclose(WV_file_id);
    
    disp ( ' ' );

    % keep the local waveform file if required
    if (KeepLocalFile ~= 1)
        disp('Deleting local waveform file...');
        delete (sprintf('%s', IQinfo.filename));
    end

    % terminate transfer for tcpip (no EOIMode for tcpip objects)
    if (strcmp(get(InstrObj,'Type'),'tcpip')==1)
         fwrite (InstrObj, 13, 'uchar');            % send CR
         fwrite (InstrObj, 10, 'uchar');            % send LF
    end
    
    % set back to old state 
    if (strcmp(get(InstrObj,'Type'),'tcpip')==0)
        InstrObj.EOIMode = EoiStat;
    end
     
    % for GPIB connections turn back to standard
    if( strcmp(get(InstrObj,'Type'),'gpib')==1 || strcmp(get(InstrObj,'Type'),'visa-gpib')==1 )
        [stat, Result] = rs_send_query (InstrObj, ':SYST:COMM:GPIB:LTER STAN; *OPC?');
        if( (stat < 1) || (Result(1) ~= '1') )
            fclose (InstrObj);
            disp ('*** Cannot set instrument LTER mode.'); 
            return;
        end
    end
   
    stat = read_error_queue (InstrObj);
    if (stat < 1)
        fclose (InstrObj);
        disp ('*** Instrument errors occured.');
        return;
    end
     
    % activate playback if required
    stat = 1;
    
    if (StartPlayback==1)
        stat = StartARB (InstrObj, '1', IQinfo.path, IQinfo.filename);
    end
    if (StartPlayback==2)
        stat = StartARB (InstrObj, '2', IQinfo.path, IQinfo.filename);
    end
    
    if (stat < 1)
        fclose (InstrObj);
        disp ('*** Cannot start ARB.');
        return;
    end
    
    disp('Closing instrument connection...');

    % close connection
    try
        fclose (InstrObj);
    catch err
        disp ('*** Failed to close instrument connection.');
        disp (['*** Matlab error message : ' err.message]);
        return;
    end
   
    Status = 1;

return;

%
% function - activate playback on SMU, SMJ, SMATE, SMBV
%
function [Status] = StartARB( InstrObj, num, path, filename )
    
    Status = 0;
     
    % query instrument type
    [stat, Result] = rs_send_query (InstrObj,'*IDN?');
    if (stat<0), return; end
    
    % determine if this is an AFQ instrument
    if (isempty(strfind(Result, 'AFQ100')))
        
        disp ('Activating SMW/SMBV ARB...');
        [stat, Result] = rs_send_query (InstrObj, sprintf(':SOUR%s:BB:ARB:WAV:SEL ''%s%s''; *OPC?',num,path,filename));
        if (stat<0 || Result(1)~='1'), return; end
        [stat, Result]= rs_send_query (InstrObj, sprintf(':SOUR%s:BB:ARB:STAT ON; *OPC?', num));
        if (stat<0 || Result(1)~='1'), return; end
        [stat, Result] = rs_send_query (InstrObj, sprintf(':OUTP%s:STAT ON; *OPC?', num));
        if (stat<0 || Result(1)~='1'), return; end
        
    else
        
        disp ('Activating AFQ ARB...');
        [stat, Result] = rs_send_query (InstrObj, sprintf('WAV:SEL ''%s%s''; *OPC?',path,filename));
        if (stat<0 || Result(1)~='1'), return; end
        [stat, Result] = rs_send_query (InstrObj, sprintf('SOUR:STATE ON; *OPC?'));
        if (stat<0 || Result(1)~='1'), return; end
        
    end
    
    Status = 1;
    
return;

%
% function - check marker array
%
function valid = check_marker_array(marray)
    
    valid = 0;
    
    if (isnumeric(marray) ~= 1)
        disp('Marker list must contain numeric values.');
        return
    end
    if ((size(marray(:,1),1)) ~= (size(marray(:,2),1)))
        disp('Marker list must contain pairs [Position Value] of values.');
        return
    end
    for i=1:1:size(marray(:,2))
        if (~((marray(i,2) == 1) || (marray(i,2) == 0)))
            disp('Marker value must be binary.');
            return
        end
    end
    
    valid = 1;
    
return;

%
% function - building marker
%
function mstring = build_marker_string(marray)

    mstring = '';
    for i=1:1:size(marray,1)-1
        mstring = sprintf('%s%u:%u;',mstring,marray(i,1),marray(i,2));
    end
    mstring = sprintf('%s%u:%u',mstring,marray(size(marray,1),1),marray(size(marray,1),2));
    
return;

%
% function - read error queue
%
function [Status] = read_error_queue(InstrObj)
    
    Status = 0;
    Errors = 0;
    answer = 'error';
    
    while answer(1) ~= '0'
        [stat, answer] = rs_send_query (InstrObj, 'SYST:ERR?');
        if (stat < 1)
            disp ('*** Cannot read instrument error queue.');
            return;
        end
        if (answer(1) ~= '0')
            disp (['*** Instrument Error: ' answer]);
            Errors = Errors + 1;
        end
    end

    if (Errors == 0)
        Status = 1;
    end
    
return;

% end of file
