function [SeqCmdStr, BlockCmdStr] = get_sequence_block_cmd(trials, blockLength, seqProb0, seqProb1, seqInd0, seqInd1)
%GET_SEQUENCE_CMD Summary of this function goes here
%   Detailed explanation goes here

    if ~exist('seqInd0', 'var')
        seqInd0 = cell(size(seqProb0));
    end
    if ~exist('seqInd1', 'var')
        seqInd1 = cell(size(seqProb1));
    end

%     blockType = mod(floor(trialNum/40), 2);
    blockType = trials(end);
    if numel(unique(trials)) == 1
        currBlock = numel(trials);
    else
        currBlock = numel(trials) - find(trials ~= trials(end), 1, 'last'); % Length of current block
    end
    if currBlock >= blockLength * 0.9 % Block lengths will vary randomly by +- 10%
        if rand(1) < (currBlock - blockLength * 0.9)/(blockLength * 0.2 + 1)
            blockType = ~trials(end);
        else
            blockType = trials(end);
        end
    end

    % Parameters
    if blockType % blockType=0 for the first block, 1 for the second block
        seqProb = seqProb1;
        seqInd = seqInd1;
    else
        seqProb = seqProb0;
        seqInd = seqInd0;
    end

    % Generate a random sequence
    switch find(rand(1) < cumsum(seqProb), 1)
        case 1
            % regular
            seqVect = [4 3 2 1 0];
            
        case 2
            % backtracking 1
            seqVect = [4 3 2 3 1 0];
            
        case 3
            % backtracking 2
            seqVect = [4 3 2 1 2 0];
            
        case 4
            % forward-jumping
            seqVect = [4 3 2 0];
            
    end

    % % Overwrite with a deterministic sequence
    % if ismember(trialNum, seqInd{1})
    %     % regular
    %     seqVect = 0:6;
    % elseif ismember(trialNum, seqInd{2})
    %     % backtracking
    %     seqVect = [0:3 1 4:6];
    % elseif ismember(trialNum, seqInd{3})
    %     % forward-jumping
    %     seqVect = [0:3 5:6];
    % end

    % Make block type command string
    if blockType ~= trials(end)
        BlockCmdStr = ['Blk,', num2str(blockType)];
    else
        BlockCmdStr = [];
    end
    
    % Make Seq type command string
    cmdTag = 'Seq1';
    cmdTag = {cmdTag};
    seqVect = arrayfun(@num2str, seqVect, 'Uni', false);
    SeqCmdStr = strjoin([cmdTag, seqVect], ',');
        
end




