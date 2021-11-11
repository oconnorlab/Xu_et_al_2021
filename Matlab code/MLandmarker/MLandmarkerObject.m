classdef MLandmarkerObject < handle
    %MLandmarkerObject Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        tb;
    end
    
    properties(Dependent)
        maxNumPoints;
    end
    
    methods
        function val = get.maxNumPoints(this)
            val = max(cellfun(@(x) size(x,1), this.tb{:,1}));
        end
    end
    
    methods
        function this = MLandmarkerObject(lmColumn)
            % Constructor
            this.tb = lmColumn;
        end
        
        function coor = GetCoordinates(this, frIdx)
            coor = this.tb{frIdx,1}{1};
        end
        
        function idx = GetNextPointIndex(this, frIdx)
            coor = this.GetCoordinates(frIdx);
            idx = size(coor,1) + 1;
        end
        
        function ptList = GetPointList(this, frIdx)
            idx = this.GetNextPointIndex(frIdx);
            ptList = arrayfun(@num2str, 1:idx, 'Uni', false)';
        end
        
        function isDoable = SetPoint(this, frIdx, ptIdx, pos)
            
            coor = this.GetCoordinates(frIdx);
            
            % Only allow to set at most one point beyound the current number of points
            isDoable = ptIdx <= size(coor,1) + 1;
            
            % Check for max number of points unless it is the initial frame
            coorLens = cellfun(@(x) size(x,1), this.tb{:,1});
            if sum(coorLens > 0) > 1
                isDoable = isDoable && ptIdx <= max(coorLens);
            end
            
            % Apply point
            if isDoable
                coor(ptIdx,:) = pos;
                this.SetCoordinates(frIdx, coor);
            end
        end
        
        function isDoable = GeneratePoints(this, frIdx)
            
            maxNum = this.maxNumPoints;
            
            % Require at least four frames of full number data for interpolation
            coorLens = cellfun(@(x) size(x,1), this.tb{:,1});
            indFull = find(coorLens == maxNum);
            isDoable = maxNum > 0 && numel(indFull) > 3;
            
            if ~isDoable
                return;
            end
            
            % Interpolation
            coorFull = this.tb{indFull,1};
            coorFull = cell2mat(cellfun(@(x) x(:)', coorFull(:), 'Uni', false));
            coorQuery = interp1(indFull, coorFull, frIdx, 'pchip');
            coorQuery = reshape(coorQuery, maxNum, 2);
            
            % Assign unmarked points
            coor = this.GetCoordinates(frIdx);
            coor = cat(1, coor, coorQuery(size(coor,1)+1:end,:));
            this.SetCoordinates(frIdx, coor);
        end
        
        function isDoable = ClearLastPoint(this, frIdx)
            
            coor = this.GetCoordinates(frIdx);
            
            isDoable = ~isempty(coor);
            
            if isDoable
                this.SetCoordinates(frIdx, coor(1:end-1,:));
            end
        end
        
        function isDoable = ClearAllPoint(this, frIdx)
            
            coor = this.GetCoordinates(frIdx);
            
            isDoable = ~isempty(coor);
            
            if isDoable
                this.SetCoordinates(frIdx, zeros(0,2));
            end
        end
        
        function ShowProfile(this)
            
            objName = this.tb.Properties.VariableNames{1};
            coorLens = cellfun(@(x) size(x,1), this.tb{:,1});
            maxLen = max(coorLens);
            numFinished = sum(coorLens > 0 & coorLens == maxLen);
            
            figure(sum(objName));
            plot(coorLens, 'o-', 'Color', ones(1,3)*.7, 'MarkerEdgeColor', 'k');
            xlabel('Frame');
            ylabel('Number of points');
            axis tight
            ylim([-1, maxLen+1]);
            title([num2str(numFinished) ' frames finished']);
        end
    end
    
    methods(Access = private)
        function SetCoordinates(this, frIdx, coor)
            this.tb{frIdx,1}{1} = coor;
        end
    end
    
end

