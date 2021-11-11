function SL_Block(obj)
%SL_RR_Half Summary of this function goes here
%   Detailed explanation goes here


% Initialize figure and plots if absent
if any(~isfield(obj.userData, {'fig', 'axes1', 't0', 'lickportPos'})) ...
        || ~ishandle(obj.userData.fig)
    % Create GUI
    obj.userData.fig = figure;
    obj.userData.fig.Name = obj.channelName;
    
    obj.userData.axes1 = axes();
    obj.userData.axes1.XLim = [0 5];
    hold(obj.userData.axes1, 'on');
    xlabel(obj.userData.axes1, 'time (s)');
    ylabel(obj.userData.axes1, 'position (degree)');
    title(obj.userData.axes1, 'Trial 0');
    
    % Runtime variables
    obj.userData.trialNum = 0;
    obj.userData.t0 = 0;
    obj.userData.lickportPos = NaN;
    obj.userData.trials = [double(rand(1) > 0.5)];
    obj.userData.angles = {};
end


% Make shorthand version of variables for clarity
ax1 = obj.userData.axes1;
trialNum = obj.userData.trialNum;
t0 = obj.userData.t0;
lickportPos = obj.userData.lickportPos;
isDisp = obj.isDisplay;


% Split incoming string
ss = strsplit(obj.msgIn, ',');
ss(2:end) = cellfun(@str2double, ss(2:end), 'Uni', false);


% Update plot based on incoming string
if obj.BeginWith('a,')
    % store angles/positions of sequences
    obj.userData.angles{end+1} = ss{3};
    
elseif obj.BeginWith('lickOn,')
    % Plot lick
    tLick = ss{2} / 1000 - t0;
    plot(ax1, tLick, lickportPos, 'k*');
    
    if tLick > ax1.XLim(2)
        ax1.XLim(2) = tLick + 5;
    end
    isDisp = false;
    
elseif obj.BeginWith('lickOff,')
    % Supress display
    isDisp = false;
    
elseif obj.BeginWith('sessionStart,')
    % Initiate trial history var
    obj.userData.trials = [double(rand(1) > 0.5)];
    obj.SendMessage(['Blk,', num2str(obj.userData.trials)]);
    
elseif obj.BeginWith('trialNum,')
    % Clear plot for a new trial
    cla(ax1);
    ax1.XLim = [0 5];
    t0 = ss{2} / 1000;
    trialNum = ss{3};
    title(ax1, ['Trial ' num2str(trialNum)]);
    
elseif obj.BeginWith('angle,')
    % Plot lickport movement
    tOn = ss{2} / 1000 - t0;
    lickportPos = ss{3};
    plot(ax1, tOn, lickportPos, '>', 'Color', [0 .7 0], 'MarkerSize', 6);
    
    if tOn > ax1.XLim(2)
        ax1.XLim(2) = tOn + 5;
    end
    
    if lickportPos > ax1.YLim(2)
        ax1.YLim(2) = lickportPos + 1;
    end
    
    if lickportPos < ax1.YLim(1)
        ax1.YLim(1) = lickportPos - 1;
    end
    
elseif obj.BeginWith('cue,')
    % Plot cue
    tOn = ss{2} / 1000 - t0;
    dur = ss{3} / 1000;
    lickportPos = obj.userData.angles{end};
    plot(ax1, [tOn; tOn+dur], [lickportPos; lickportPos], '-m', 'LineWidth', 4);
    
    if tOn+dur > ax1.XLim(2)
        ax1.XLim(2) = tOn + dur + 5;
    end
    
elseif obj.BeginWith('water,')
    % Plot water
    tOn = ss{2} / 1000 - t0;
    dur = ss{3} / 1000;
    plot(ax1, [tOn; tOn+dur], [lickportPos; lickportPos], '-b', 'LineWidth', 4);
    
    if tOn+dur > ax1.XLim(2)
        ax1.XLim(2) = tOn + dur + 5;
    end
    
    % Update sequence
    seqProb0 = [1/2 1/2 0 0]; 
    seqProb1 = [1/2 1/2 0 0];
    blockLength = 40;
    [seqCmd, blkCmd] = get_sequence_block_cmd(obj.userData.trials, blockLength, seqProb0, seqProb1);
    if ~isempty (blkCmd)
        obj.SendMessage(blkCmd);
        obj.userData.trials = [obj.userData.trials, ~obj.userData.trials(end)];
    else
        obj.userData.trials = [obj.userData.trials, obj.userData.trials(end)];
    end
    obj.SendMessage(seqCmd);
    
elseif obj.BeginWith('opto,')
    % Plot lick
    tOpto = ss{2} / 1000 - t0;
    plot(ax1, tOpto, lickportPos, 'cs', 'MarkerFaceColor', 'c', 'MarkerSize', 10);
    
    if tOpto > ax1.XLim(2)
        ax1.XLim(2) = tOpto + 5;
    end
    
elseif obj.BeginWith('sessionEnd,')
    % clear angles/positions of current session
    obj.userData.angles = {};
end


% Assign shorthand variables back
obj.userData.trialNum = trialNum;
obj.userData.t0 = t0;
obj.userData.lickportPos = lickportPos;
obj.isDisplay = isDisp;



end
