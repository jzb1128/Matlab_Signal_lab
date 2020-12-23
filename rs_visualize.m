% function rs_visualize
% *************************************************************************
% 
% Copyright: (c) 2011 Rohde & Schwarz GmbH & CO KG.    All rights reserved.
%                Muehldorfstr. 15
%                D-81671 Munich
%
% *************************************************************************
% This function visualizes I/Q data by plotting the I/Q traces versus time,
% the FFT spectrum and a density plot.
%%
% @param Fsample        Sample rate
% @param I_data         I samples
% @param Q_data         Q samples
%%
% @return Status      Status = 0, failure
%                     Status = 1, success
% *************************************************************************
function [Status] = rs_visualize( Fsample, I_data, Q_data )  

    Status = 1;
    
    disp('Plotting I/Q Data');

    % check if the statistics toolbox is there
    StatInstalled = license( 'checkout', 'statistics_toolbox' );

    % time scale
    Time = 0:1.0/Fsample:(length(I_data)-1)/Fsample;

    % if max value of the envelope is greater than 1.0
    % all IQ data must be normalized.
    max_IQ_data = max( abs( I_data + 1i*Q_data ) );
    if max_IQ_data > 1.0
        I_data = I_data / max_IQ_data;
        Q_data = Q_data / max_IQ_data;
    end

    % plot I/Q data
    subplot( 2, 2, [1 2] );
    hold all;
    grid on
    p1 = plot( Time, I_data );
    p2 = plot( Time, Q_data );
    set( p1, 'Color', 'red', 'LineWidth', 2 );
    set( p2, 'Color', 'blue', 'LineWidth', 2 );
    title( 'I(t), Q(t)', 'FontSize', 8 );
    xlabel( 'Time / s' )
    ylabel( 'Amplitude' )

    % compute FFT
    IQdata    = complex( I_data, Q_data );
    FFTData   = fftshift( fft( IQdata ) );
    Pyy       = 30 + 10 * log10( 1e-32+abs( FFTData ) / length( I_data ) );
    FreqScale = -Fsample/2:Fsample/length(Pyy):Fsample/2-Fsample/length(Pyy);

    % plot FFT
    subplot( 2, 2, 3 );
    p = plot( FreqScale, Pyy );
    set( p, 'Color', 'blue', 'LineWidth', 2 );
    grid on;
    title( 'FFT', 'FontSize', 8 );
    xlabel( 'Frequency / Hz' )
    ylabel( 'Level / dB' )

    % plot I/Q plane density chart
    if StatInstalled
        
        maxval          = max( abs( I_data + 1i*Q_data ) ) + 1e-32;
        VectorData      = horzcat( (I_data/maxval)', (Q_data/maxval)' );
 
        HistogramData   = hist3( VectorData, {-1.1:0.05:1.1 -1.1:0.05:1.1} )';
        xb              = linspace( -1.1, 1.1, 45 );
        yb              = linspace( -1.1, 1.1, 45 );
        HistogramData   = 10 * log10( HistogramData );
        
        subplot( 2, 2, 4 );
        PseudoColorPlot = pcolor( xb, yb, HistogramData ); 
        set( PseudoColorPlot, 'zdata', ones( size(HistogramData) ) * -max( max( HistogramData ) ) ); 
        shading flat; 
        colormap( jet ); 
        title( 'I/Q Plane' );
        view( 2 );
        
    else
        disp('Statistics package not installed.');
    end

return



