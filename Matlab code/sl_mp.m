%% SE info

if ~exist('mp', 'var')
    load('sl mp full.mat');
end
if ~exist('se', 'var')
    se = SL.SE.LoadSession();
end
SL.SE.GetSessionInfoTable(se)


%% SE Sorting

[bt, bv] = se.GetTable('behavTime', 'behavValue');

tbSort = table(bv.seqId, bv.opto, bt.water);
% tbSort = table(bv.seqId, bv.opto, bt.waterTrig - cellfun(@(x) x(1), bt.posIndex));
% tbSort = table(bv.optoMod1, bt.water);
[~, ind] = sortrows(tbSort, tbSort.Properties.VariableNames, 'ascend');

se.SortEpochs(ind);


%% SE alignment

bt = se.GetTable('behavTime');
se.RemoveEpochs(isnan(bt.water));

bt = se.GetTable('behavTime');
seqPos1 = cellfun(@(x) x(1), bt.posIndex);
seqPosMid = cellfun(@(x) x(4), bt.posIndex);

se.AlignTime(bt.cue);
% se.AlignTime(seqPos1);
% se.AlignTime(seqPosMid);
% se.AlignTime(bt.water);
% se.AlignTime(bt.opto);


return

%% Save video

% Unified figure sizes
f = figure(1);
f.Color = 'w';

tightfig(f)
f.Position(3:4) = [4 3]*130;

tightfig(f)
f.Position(3:4) = [4 3]*150


%{

xSlow = 5;
stepTime = 1/400 * (400/xSlow)/30

vidMat = mp.MakeVideo(f, stepTime);

vidObj = VideoWriter('D:\vid.avi');
vidObj.Quality = 95;
vidObj.FrameRate = 30;

open(vidObj);
writeVideo(vidObj, vidMat);
close(vidObj);

disp('finished');

%}

