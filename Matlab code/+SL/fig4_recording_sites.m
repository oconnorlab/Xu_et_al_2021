%% Plot recording sites

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig4');


%% Load data

dataSource = SL.Data.FindSessions('fig4_recording_sites');

xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Si');
isIncluded = false(height(xlsTb), 1);
for i = 1 : height(xlsTb)
    sId = SL.SE.GetID(xlsTb.animal_id{i}, xlsTb.date(i));
    numHit = sum(strcmp(sId, dataSource.sessionId));
    if numHit == 1
        isIncluded(i) = true;
    elseif numHit > 1
        error('Found %d sessions named after %s', sum(isHit), sId);
    end
end
xlsTb = xlsTb(isIncluded,:);
xlsTb.area = strrep(xlsTb.area, '/', '_');


%% Plot

% Convert coordinates to numbers
histCoor = cell2mat(cellfun(@eval, xlsTb.hist_coor, 'Uni', false));
isLeft = strcmp(xlsTb.hemisphere, 'left');
histCoor(isLeft,2) = -histCoor(isLeft,2);

% Invert lateral coordinates for left hemisphere
% hemi = categorical(xlsTb.hemisphere);
% histCoor(hemi == 'left', 2) = -histCoor(hemi == 'left',2);

% Jitter coordinates to avoid overlap
rng(61);
histCoor = histCoor + (rand(size(histCoor))-.5)*0.1;

% 
penetDepth = -xlsTb.penet_depth / 1e3;


% Plotting parameters
% cmap = lines(6);
% areaCC = struct();
% areaCC.ALM = cmap(2,:);   % orange
% areaCC.M1TJ = cmap(3,:);  % yellow
% areaCC.S1TJ = cmap(1,:);  % blue
% areaCC.S1BF = cmap(4,:);  % purple
% areaCC.M1B = cmap(5,:);   % green
% areaCC.S1L = cmap(6,:);   % cyan
% areaCC.M1 = [0 0 0];
% areaCC.M2 = [0 0 0];
% areaCC.S1Tr = [0 0 0];
% areaCC.VAL = [0 0 0] + .7;
% areaCC.VPM_PO = [0 0 0] + .7;
% areaCC.striatum = [0 0 0] + .7;
% areaCC.GP = [0 0 0] + .7;
% area2plot = fieldnames(areaCC);

area2plot = {'ALM', 'M1TJ', 'S1TJ', 'S1BF', 'M1B', 'S1L', 'M1', 'M2', 'S1Tr'}; % 'VAL', 'VPM_PO', 'striatum', 'GP'
bEdges = -3 : .25 : 3.5;
lEdges = 0 : .25 : 4;

% Plot
f = MPlot.Figure(31113); clf

imageName = 'Allen CCF dorsal view white.tif';
img = imread(imageName);
scale = size(img,2)/10; % pixel/mm
topBreg = 5.45; % mm
x = (1:size(img,2))' / scale;
x = x - max(x)/2;
y = (1:size(img,1))' / scale;
y = -(y - topBreg);
image(x, y, img(:,:,1:3)); hold on
axis equal xy tight off

for i = 1 : numel(area2plot)
    ind = strcmp(area2plot{i}, xlsTb.area);
    cc = SL.Param.GetAreaColors(area2plot{i});
    plot(histCoor(ind,2), histCoor(ind,1), 'o', 'Color', cc, 'MarkerSize', 4);
    hold on
end

plot([0 -1; 0 1]*.5, [-1 0; 1 0]*.5, 'k', 'LineWidth', 1);

MPlot.Paperize(f, 'ColumnsWide', .5, 'ColumnsHigh', .33);
saveFigurePDF(f, fullfile(figDir, 'recording sites on brain'));

