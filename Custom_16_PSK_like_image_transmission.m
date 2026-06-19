%% Custom 16-PSK-like Image Transmission
% In this project, a grayscale image is transmitted using a custom
% non-uniform 16-PSK-like constellation over a noisy communication link.
%
% The report is organized according to the required sections:
%
% a) Constellation Design
%
% b) Encoding Rule (Modulator)
%
% c) Decoding Rule (Demodulator)
%
% d) BER Simulation Results
%
% e) BER Curve Fitting
%
% f) Image Reconstruction Results

clear
close all
clc

%% Program Initialization
% In this project, a 16-point constellation is used, so each symbol carries 4 bits.

seedValue = 12345;          % Anonymous fixed seed
rng(seedValue);             % Makes random results reproducible

M = 16;                     % Number of constellation points
bitsPerSymbol = 4;          % log2(16) = 4 bits per symbol
bitsPerPixel = 8;           % Grayscale image uses 8 bits per pixel

SNR_dB_values = 0:5:40;     % Required SNR values
selectedSNRs = [0 20 40];   % SNR values selected for example plots/images

%% Read and Prepare the Grayscale Image
% 50 by 50 portion of the image is extracted.

Im = imread('cameraman.tif');

% Extract a 50x50 grayscale image
Im = Im(51:100,101:150);

% Store image as uint8
Im = uint8(Im);

figure
imshow(Im)
title('Original Transmitted Image')

%% Convert Image to Bit Stream
% Each pixel of the grayscale image is represented using 8 bits. The image
% matrix is first converted into a column vector. Then, each pixel value is
% converted into its binary representation manually.
%

Imv = Im(:);
numPixels = length(Imv);

s = zeros(1,numPixels*bitsPerPixel);

for k = 1:numPixels
    pixelValue = Imv(k);

    for b = 1:bitsPerPixel
        s((k-1)*bitsPerPixel + b) = bitget(pixelValue,bitsPerPixel-b+1);
    end
end

numBits = length(s);
numSymbols = numBits/bitsPerSymbol;

fprintf('Total number of pixels = %d\n', numPixels);
fprintf('Total number of transmitted bits = %d\n', numBits);
fprintf('Total number of transmitted symbols = %d\n', numSymbols);

%% a) Constellation Design
% In this section, a custom non-uniform 16-PSK-like constellation is
% designed.
%
% First, 16 ideal PSK points are placed uniformly on the unit circle. 
%
% Then, each ideal angle is randomly perturbed by a value between -5 degrees
% and +5 degrees. The random seed is fixed, so the same seed always generates 
% the same constellation.
%
% Each constellation point has unit magnitude and can be written as:
%
% $$s_k = e^{j\theta_k}$$
%
% where $\theta_k$ is the perturbed angle of the kth constellation point.

idealAngles_deg = (0:M-1)*(360/M);

% Random perturbation between -5 and +5 degrees
anglePerturbation_deg = -5 + 10*rand(1,M);

% Actual perturbed angles
actualAngles_deg = idealAngles_deg + anglePerturbation_deg;
actualAngles_rad = actualAngles_deg*pi/180;

% Unit-circle constellation points
constellation = exp(1j*actualAngles_rad);

%% Gray Code Assignment
% A unique 4-bit Gray code is assigned to each constellation point.
%
% Gray coding is useful because adjacent constellation points differ by only
% one bit in the ideal angular ordering. Therefore, if noise causes a symbol
% to be decoded as a neighboring point, the number of bit errors is reduced.

grayLabels = zeros(M,bitsPerSymbol);

for n = 0:M-1
    grayValue = bitxor(n,floor(n/2));

    for b = 1:bitsPerSymbol
        grayLabels(n+1,b) = bitget(grayValue,bitsPerSymbol-b+1);
    end
end

%% a) Constellation Point Table
% The following table lists each constellation point, its angle in degrees,
% its complex coordinates, and its assigned 4-bit Gray code label.

fprintf('\n');
fprintf('a) Constellation Design Table\n');
fprintf('-------------------------------------------------------------\n');
fprintf('Index\tAngle(deg)\tReal Part\tImag Part\tGray Label\n');

for k = 1:M
    labelStr = sprintf('%d%d%d%d',grayLabels(k,1),grayLabels(k,2), ...
                                grayLabels(k,3),grayLabels(k,4));

    fprintf('%2d\t%9.3f\t%9.4f\t%9.4f\t%s\n', ...
        k, actualAngles_deg(k), real(constellation(k)), ...
        imag(constellation(k)), labelStr);
end

%% a) Constellation Diagram
% The following figure shows the custom non-uniform 16-PSK-like
% constellation. Each red point represents one constellation symbol and is
% labeled with its assigned 4-bit Gray code.

figure
plot(real(constellation),imag(constellation),'ro','LineWidth',1.5)
hold on
grid on
axis equal

thetaCircle = linspace(0,2*pi,500);
plot(cos(thetaCircle),sin(thetaCircle),'k--')

for k = 1:M
    labelStr = sprintf('%d%d%d%d',grayLabels(k,1),grayLabels(k,2), ...
                                grayLabels(k,3),grayLabels(k,4));

    text(1.12*real(constellation(k)), ...
         1.12*imag(constellation(k)), ...
         labelStr)
end

xlabel('Real Part')
ylabel('Imaginary Part')
title('a) Custom Non-Uniform 16-PSK-like Constellation')
hold off

%% b) Encoding Rule (Modulator)
% In this section, the custom modulator is implemented.
%
% Since the modulation order is 16, each transmitted symbol represents 4
% bits. Therefore, the input bit stream is divided into groups of 4 bits.
%
% Each 4-bit group is compared with the Gray code labels. The constellation
% point with the matching Gray label is selected as the transmitted complex
% symbol.
%
% The encoding rule can be summarized as:
%
% $$\textrm{input 4-bit group} \rightarrow \textrm{corresponding complex symbol}$$

sv = reshape(s,bitsPerSymbol,numSymbols);

c = zeros(1,numSymbols);

for k = 1:numSymbols

    inputBits = sv(:,k).';

    symbolIndex = 0;

    for m = 1:M
        if isequal(inputBits,grayLabels(m,:))
            symbolIndex = m;
            break
        end
    end

    c(k) = constellation(symbolIndex);
end

%% b) Modulator Mapping Table
% The following table shows the complete mapping used by the modulator.
% Each 4-bit input group is mapped to a complex constellation point.

fprintf('\n');
fprintf('b) Encoding Rule / Modulator Mapping Table\n');
fprintf('-------------------------------------------------------------\n');
fprintf('Input Bits\tSymbol Real\tSymbol Imag\tAngle(deg)\n');

for k = 1:M
    labelStr = sprintf('%d%d%d%d',grayLabels(k,1),grayLabels(k,2), ...
                                grayLabels(k,3),grayLabels(k,4));

    fprintf('%s\t\t%9.4f\t%9.4f\t%9.3f\n', ...
        labelStr, real(constellation(k)), ...
        imag(constellation(k)), actualAngles_deg(k));
end

%% Passband Transmission Model
% I used rectangular pulse shaping.
% Each complex symbol is repeated for Ns samples.
%
% Then, the complex baseband signal is converted into a real passband signal
% using:
%
% $$x(t)=Re\{x_b(t)\}\cos(2\pi f_c t)-Im\{x_b(t)\}\sin(2\pi f_c t)$$

Fsampling = 2^19;
Tsampling = 1/Fsampling;

Fsymbol = 2^13;
Tsymbol = 1/Fsymbol;

Ns = Tsymbol/Tsampling;

xb = kron(c,ones(1,Ns));

fc = 60e3;

t = (0:length(xb)-1)*Tsampling;

cost = cos(2*pi*fc*t);
sint = sin(2*pi*fc*t);

x = real(xb).*cost - imag(xb).*sint;

%% Baseband and Passband Signal Segments
% The following figure shows example time-domain segments of the real
% baseband component, imaginary baseband component, and passband modulated
% signal.

SL = 800;

figure
subplot(3,1,1)
plot(t(1:SL)*1000,real(xb(1:SL)))
grid on
xlabel('Time (msec)')
ylabel('Amplitude')
title('Real Part of Baseband Signal Segment')

subplot(3,1,2)
plot(t(1:SL)*1000,imag(xb(1:SL)))
grid on
xlabel('Time (msec)')
ylabel('Amplitude')
title('Imaginary Part of Baseband Signal Segment')

subplot(3,1,3)
plot(t(1:SL)*1000,x(1:SL),'r')
grid on
xlabel('Time (msec)')
ylabel('Amplitude')
title('Passband Modulated Signal Segment')

%% c) Decoding Rule (Demodulator)
% In this section, the custom demodulator is described and implemented.
%
% The noisy received passband signal is first downconverted into complex
% baseband form using coherent demodulation. Then, the receiver samples the
% baseband signal once per symbol period.
%
% The demodulator uses minimum-distance decoding. For each received noisy
% complex symbol $r$, the Euclidean distance to all constellation points is
% calculated. The closest constellation point is selected.
%

%% d) BER Simulation Results
% In this section, the BER performance is simulated.
%
% The simulation is performed for the following SNR values:
%
% 0 dB, 5 dB, 10 dB, 15 dB, 20 dB, 25 dB, 30 dB, 35 dB, and 40 dB.
%
% For each SNR value, Gaussian noise is added to the transmitted passband
% signal. Then, the received signal is demodulated and decoded using the
% minimum-distance rule.
%
% The BER is calculated as:
%
% $$BER=\frac{\textrm{Number of bit errors}}{\textrm{Total number of transmitted bits}}$$

BER_values = zeros(size(SNR_dB_values));

receivedConstellations = cell(size(selectedSNRs));
reconstructedImages = cell(size(selectedSNRs));

sigpow = mean(x.^2);

for snrIndex = 1:length(SNR_dB_values)

    SNR = SNR_dB_values(snrIndex);

    % Noise amplitude for the selected SNR
    NoiseAmp = sqrt(10^(-SNR/10)*sigpow);

    % Real Gaussian noise added to passband signal
    noise = NoiseAmp*randn(1,length(x));

    % Noisy received signal
    y = x + noise;

    % Coherent receiver: real baseband component
    ur = 2*y.*cost;
    zr = lowpass(ur,30e3,Fsampling);

    % Coherent receiver: imaginary baseband component
    ui = -2*y.*sint;
    zi = lowpass(ui,30e3,Fsampling);

    % Complex baseband estimate
    z = zr + 1j*zi;

    % Sample once per symbol, near the middle of each symbol interval
    ce = z(ceil(Ns/2):Ns:length(z));
    ce = ce(1:numSymbols);

    % Minimum-distance decoding
    se = zeros(1,numBits);

    for k = 1:numSymbols

        receivedPoint = ce(k);

        distances = abs(receivedPoint - constellation).^2;

        [~,nearestIndex] = min(distances);

        estimatedBits = grayLabels(nearestIndex,:);

        se((k-1)*bitsPerSymbol + 1 : k*bitsPerSymbol) = estimatedBits;
    end

    % BER calculation
    BER = sum(se ~= s)/numBits;
    BER_values(snrIndex) = BER;

    fprintf('SNR = %2d dB, BER = %.6e\n',SNR,BER);

    % Store selected SNR results for constellation plots and image results
    if ismember(SNR,selectedSNRs)

        selectedIndex = find(selectedSNRs == SNR);

        Imve = zeros(numPixels,1);

        for p = 1:numPixels

            pixelBits = se((p-1)*bitsPerPixel + 1 : p*bitsPerPixel);

            pixelValue = 0;

            for b = 1:bitsPerPixel
                pixelValue = pixelValue + pixelBits(b)*2^(bitsPerPixel-b);
            end

            Imve(p) = pixelValue;
        end

        Ime = reshape(Imve,size(Im));

        reconstructedImages{selectedIndex} = uint8(Ime);
        receivedConstellations{selectedIndex} = ce;
    end
end

%% d) BER Results Table
% The following table reports the measured BER value for each SNR level.

fprintf('\n');
fprintf('d) BER Simulation Results Table\n');
fprintf('--------------------------------\n');
fprintf('SNR(dB)\t\tMeasured BER\n');

for k = 1:length(SNR_dB_values)
    fprintf('%2d\t\t%.6e\n',SNR_dB_values(k),BER_values(k));
end

%% d) BER versus SNR Plot
% The following plot shows the measured BER versus SNR.
%
% Since logarithmic plots cannot display zero values, zero BER values are
% replaced by the smallest measurable BER value only for plotting. The
% actual BER values are still reported in the BER table.

berFloor = 1/numBits;

BER_for_plot = BER_values;
BER_for_plot(BER_for_plot == 0) = berFloor;

figure
semilogy(SNR_dB_values,BER_for_plot,'bo-','LineWidth',1.5)
grid on
xlabel('SNR (dB)')
ylabel('Bit Error Rate (BER)')
title('d) BER vs SNR for Custom 16-PSK-like Modulation')

%% d) Received Constellation Diagrams at Selected SNR Levels
% The following received constellation diagrams are shown for 0 dB, 20 dB,
% and 40 dB.
%
% At 0 dB, the noise power is high, so the received symbols are widely
% scattered. At 20 dB, the points are more concentrated around the correct
% constellation locations. At 40 dB, the received points are very close to
% the original constellation points.

for k = 1:length(selectedSNRs)

    figure

    ceSelected = receivedConstellations{k};

    numberToPlot = min(3000,length(ceSelected));

    plot(real(ceSelected(1:numberToPlot)), ...
         imag(ceSelected(1:numberToPlot)),'.')
    hold on

    plot(real(constellation),imag(constellation),'ro','LineWidth',1.5)

    for m = 1:M
        labelStr = sprintf('%d%d%d%d',grayLabels(m,1),grayLabels(m,2), ...
                                    grayLabels(m,3),grayLabels(m,4));

        text(1.12*real(constellation(m)), ...
             1.12*imag(constellation(m)), ...
             labelStr)
    end

    grid on
    axis equal
    xlabel('Real Part')
    ylabel('Imaginary Part')
    title(['d) Received Constellation at SNR = ',num2str(selectedSNRs(k)),' dB'])
    legend('Received Symbols','Original Constellation Points')
    hold off
end

%% e) BER Curve Fitting
% In this section, a simple analytical curve is fitted to the measured BER
% data.
%
% An exponential model is used:
%
% $$BER(SNR)=A e^{B \cdot SNR}$$
%
% Taking the natural logarithm gives:
%
% $$\ln(BER)=\ln(A)+B \cdot SNR$$
%
% Therefore, a first-order polynomial fit can be applied to the logarithm of
% the BER values.
%
% Since $\log(0)$ is undefined, zero BER values are replaced by the smallest
% measurable BER value only for the curve fitting process.

BER_for_fit = BER_values;
BER_for_fit(BER_for_fit == 0) = berFloor;

fitCoeffs = polyfit(SNR_dB_values,log(BER_for_fit),1);

B_fit = fitCoeffs(1);
A_fit = exp(fitCoeffs(2));

BER_fit = A_fit*exp(B_fit*SNR_dB_values);

fprintf('\n');
fprintf('e) Exponential BER Curve Fit\n');
fprintf('--------------------------------\n');
fprintf('BER(SNR_dB) = %.6e * exp(%.6f * SNR_dB)\n',A_fit,B_fit);

figure
semilogy(SNR_dB_values,BER_for_plot,'bo','LineWidth',1.5)
hold on
semilogy(SNR_dB_values,BER_fit,'r--','LineWidth',1.5)
grid on
xlabel('SNR (dB)')
ylabel('Bit Error Rate (BER)')
title('e) BER Curve Fitting')
legend('Measured BER','Exponential Fit','Location','southwest')
hold off

%% e) BER Trend Discussion
% The fitted exponential curve shows the general decreasing trend of BER as
% SNR increases. This behavior is expected in a digital communication
% system.
%
% At low SNR values, noise causes large deviations in the received
% constellation points. Therefore, the minimum-distance decoder makes more
% symbol and bit errors.
%
% At high SNR values, noise power is lower and the received constellation
% points are closer to the original constellation points. Therefore, the BER
% decreases. For this finite-size image transmission, the measured BER may
% become zero at sufficiently high SNR values.

%% f) Image Reconstruction Results
% In this section, the original image and the reconstructed images are
% displayed side by side.
%
% The reconstructed images are shown for selected SNR values:
%
% * 0 dB
% * 20 dB
% * 40 dB
%
% At 0 dB, many bits are detected incorrectly, so the reconstructed image is
% highly distorted. At 20 dB, the image quality improves significantly. At
% 40 dB, the reconstructed image is almost identical to the original image.

figure

subplot(1,length(selectedSNRs)+1,1)
imshow(Im)
title('Original')

for k = 1:length(selectedSNRs)

    SNR = selectedSNRs(k);
    snrIndex = find(SNR_dB_values == SNR);

    subplot(1,length(selectedSNRs)+1,k+1)
    imshow(reconstructedImages{k})
    title(['SNR = ',num2str(SNR),' dB, BER = ', ...
        num2str(BER_values(snrIndex),'%.2e')])
end

%% Conclusion
% A 16-point unit-circle constellation was generated by perturbing the ideal
% 16-PSK angles by random values between -5 and +5 degrees. A fixed anonymous 
% random seed was used, making the constellation reproducible.
%
% A unique 4-bit Gray code label was assigned to each constellation point.
% The custom modulator mapped every 4-bit input group to the corresponding
% Gray-labeled constellation point. The custom demodulator used
% minimum-distance decoding to estimate the transmitted bit groups.
%
% The BER results show that the bit error rate decreases as the SNR
% increases. The reconstructed image results also confirm this trend: the
% image is noisy and distorted at low SNR, but becomes much clearer at high
% SNR.