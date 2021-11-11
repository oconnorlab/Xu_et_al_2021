function [seqCmd, trCmd] = get_sequence_cmd(trialNum, seqProb0, seqProb1, seqInd0, seqInd1)
%GET_SEQUENCE_CMD Summary of this function goes here
%   Detailed explanation goes here

if ~exist('seqInd0', 'var')
    seqInd0 = cell(size(seqProb0));
end
if ~exist('seqInd1', 'var')
    seqInd1 = cell(size(seqProb1));
end

isRL = mod(trialNum, 2);

% Parameters
if isRL
    seqProb = seqProb0;
    seqInd = seqInd0;
else
    seqProb = seqProb1;
    seqInd = seqInd1;
end

% Generate a random sequence
switch find(rand(1) < cumsum(seqProb), 1)
    case 1
        % regular
        seqVect = [0 1 2 3 4 5 6];
        trVect =   [0 0 0 0 0 0];
    case 2
        % backtracking
        seqVect = [0 1 2 3 1 4 5 6];
        trVect =   [0 0 0 2 3 0 0];
    case 3
        % forward-jumping
        seqVect = [0 1 2 3 5 6];
        trVect =   [0 0 0 1 0];
end

% Overwrite with a deterministic sequence
if ismember(trialNum, seqInd{1})
    % regular
    seqVect = 0:6;
elseif ismember(trialNum, seqInd{2})
    % backtracking
    seqVect = [0:3 1 4:6];
elseif ismember(trialNum, seqInd{3})
    % forward-jumping
    seqVect = [0:3 5:6];
end

% Invert sequence if from left to right
if ~isRL
    seqVect = max(seqVect) - seqVect;
end

% Convert to command string
if isRL
    posTag = 'Seq0';
    trTag = 'TT0';
else
    posTag = 'Seq1';
    trTag = 'TT1';
end
seqVect = arrayfun(@num2str, seqVect, 'Uni', false);
trVect = arrayfun(@num2str, trVect, 'Uni', false);
seqCmd = strjoin([{posTag}, seqVect], ',');
trCmd = strjoin([{trTag}, trVect], ',');


end

