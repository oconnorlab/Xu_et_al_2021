%% Calibration of Perch

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig1');


%% Load recordings

rhdSearch = MBrowse.Dir2Table(fullfile(datDir, 'Data misc\Perch lickport calibration 2019-03-02\*.rhd'));
rhdPaths = fullfile(rhdSearch.folder, rhdSearch.name);

ops = MIntan.GetOptions('adc');
ops.downsampleFactor = 30e3; % downsample to 1Hz

vData = cell(size(rhdPaths));
for i = 1 : numel(rhdPaths)
    intanStruct = MIntan.ReadRhdFiles(rhdPaths{i}, ops);
    vData{i} = intanStruct.adc_data(end-1,:); % take the second last sample
end
vData = double(cell2mat(vData));


%% 2019-03-02 lickport vertical sensor

% Weights used
dw = [0 782 100 100 200 400 400 400];
w = [cumsum(dw) 0]';
mN = w / 1e6 * 9.8 * 1000; % convert to mN

% Channel indices
lpV = 1;
lpH = 2;

% Voltage change
vChange = vData - vData(1,:);
vChange = -vChange;
[fitV, r] = fit(vChange(:,lpV), mN, 'poly1');
disp(fitV);

% Plot curves
x = [0 .4];
y = feval(fitV, x);

f = MPlot.Figure(123); clf
plot(vChange(:,lpV), mN, 'kx'); hold on
plot(x, y, 'Color', [0 0 0 .15]);
ax = MPlot.Axes(gca);
ax.YLim = [0 25];
ax.XLim = x;
xlabel('Voltage (V)');
ylabel('Force (mN)');
title("R^2 = " + r.adjrsquare);
MPlot.Paperize(f, 'ColumnsWide', .33, 'AspectRatio', .9);
saveFigurePDF(f, fullfile(figDir, 'perch calib'));

%{

Results

Maximal weight tested: 2.382g

Linear model Poly1:
fitV(x) = p1*x + p2
Coefficients (with 95% confidence bounds):
p1 =        62.3  (61.77, 62.82)
p2 =      0.1265  (0.01835, 0.2347)

sse: 0.0443
rsquare: 0.9999
dfe: 7
adjrsquare: 0.9999
rmse: 0.0795

%}


