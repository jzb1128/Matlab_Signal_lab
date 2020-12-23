% function rs_send_query
% *************************************************************************
% 
% Copyright: (c) 2011 Rohde & Schwarz GmbH & CO KG.    All rights reserved.
%                Muehldorfstr. 15
%                D-81671 Munich
%
% ************************************************************************* 
% This function is used to transmit queries to a remote instrument. 
%%
% @param InstrObj    Object for remote instrument created by rs_connect.
% @param strCommand  The SCPI command string.
%%
% @return Status     Status = 0, if query could not be transmitted.
%                    Status = 1, if query was sent successfully.
%**************************************************************************

function [Status, Result] = rs_send_query( InstrObj, strCommand )

    Status = 0;
    Result = '';

    % check number of arguments
    if( nargin ~= 2 )
        disp( '*** Wrong number of input arguments to rs_send_query().' )
        return;
    end

    % check first argument to be an object
    if( isobject(InstrObj) ~= 1 )
        disp( '*** The first parameter is not an object.' );
        return;
    end
    if( isvalid(InstrObj) ~= 1 )
        disp( '*** The first parameter is not a valid object.' );
        return;
    end

    % check command to be a string
    if( isempty(strCommand) || (ischar(strCommand)~= 1) )
        disp( '*** Command string is empty or not a string.' );
        return;
    end

    % check if question mark is present
    if( isempty( strfind(strCommand, '?' ) ) )
        disp( '*** Queries must end with a question mark.' );
        return;
    end
    
    % open instrument connection
    CloseConn = 0;
    if( ~strcmp( InstrObj.Status, 'open' ) )
        try
            fopen( InstrObj );
        catch err
            disp( '*** Cannot open instrument connection.' );
            disp (['*** Matlab error message : ' err.message]);
            return;
        end
        CloseConn = 1;
    end

    % perform query
    try
        [Result, count, msg] = query (InstrObj, strCommand);
    catch err
        disp( '*** Cannot query instrument.' );
        disp( ['*** Matlab error message : ' err.message] );
        disp( [ '*** Query string was ''' strCommand '''' ] );
        if( CloseConn ), fclose( InstrObj ); end
        return;
    end

    % close connection
    if( CloseConn )
        try
            fclose( InstrObj );
        catch err
            disp( '*** Cannot close instrument connection.' );
            disp( ['*** Matlab error message : ' err.message] );
            return;
        end
    end
    
    % check count and message
    if( count == 0 )
        disp (['*** No data read from instrument on query: ' strCommand]);
        disp (['*** Error message: ' msg]);
        return;
    end

    % set return status
    Status = 1;

    return;

