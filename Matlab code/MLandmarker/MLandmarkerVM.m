classdef MLandmarkerVM < handle
    %MARTINYVM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        vid;
        objNames;
        landmarksFileName;
        landmarks;
        landmarks2;
        
        currentFrame = 1;
        currentObject = 1;
        currentPoint = 1;
        isEnable = 0;
        isCompare = 0;
        isShowNumber = 1;
        
        handles;
        handleImage;
        handleLandmarks = {};
        handleLandmarks2 = {};
    end
    
    properties(Dependent)
        vidName;
        vidSize;
        hasImage;
        hasConfig;
        hasLandmarks;
        hasLandmarks2;
    end
    
    methods
        function val = get.vidName(this)
            if this.hasImage
                [~, val] = fileparts(this.vid.filePath);
            else
                val = 'MLandmarker';
            end
        end
        function val = get.vidSize(this)
            if this.hasImage
                val = this.vid.imgSize;
            else
                val = [0 0 0];
            end
        end
        function val = get.hasImage(this)
            val = ~isempty(this.vid);
        end
        function val = get.hasConfig(this)
            val = ~isempty(this.objNames);
        end
        function val = get.hasLandmarks(this)
            val = ~isempty(this.landmarks);
        end
        function val = get.hasLandmarks2(this)
            val = ~isempty(this.landmarks2);
        end
    end
    
    methods
        function this = MLandmarkerVM(hh)
            % Constructor
            this.handles = hh;
        end
        
        function LoadConfiguration(this)
            % Load configuration
            
            cfgPath = MBrowse.File([], 'Select a MATLAB script', {'*.m'});
            
            if ~exist(cfgPath, 'file')
                return;
            end
            
            try
                run(cfgPath);
                this.objNames = objectList;
                this.InitLandmarks();
                set(this.handles.objectListbox, 'String', this.objNames);
                set(this.handles.objectListbox, 'Value', this.currentObject);
            catch e
                disp(e);
            end
        end
        
        function LoadImage(this)
            % Load image
            
            [filePath, ~, ~, ext] = MBrowse.File([], 'Please select a AVI or TIFF file');
            
            if ~exist(filePath, 'file')
                return;
            end
            
            try
                % Delete previous objects
                if isa(this.vid, 'TiffNow')
                    delete(this.vid);
                    pause(0.5);
                end
                this.vid = [];
                
                % Load video from AVI or TIFF file
                if strcmpi(ext, '.avi')
                    this.vid.img = MNN.ReadVideo(filePath, 'FrameFunc', @rgb2gray);
                    this.vid.filePath = filePath;
                    this.vid.imgSize = size(this.vid.img);
                elseif any(strcmpi(ext, {'.tif', '.tiff'})) 
                    this.vid = TiffNow(filePath, 'loadingInterval', 0.15);
                else
                    error('Incorrect file format');
                end
                
                % Initialize display
                this.currentFrame = 1;
                this.InitLandmarks();
                
                delete(this.handleImage);
                this.handleImage = [];
                this.Refresh();
                set(this.handles.figure1, 'Name', this.vidName);
                set(this.handles.frameNumText, 'String', ['/ ' num2str(this.vidSize(3)) ' frames']);
            catch e
                assignin('base', 'e', e);
                disp(e);
            end
        end
        
        function InitLandmarks(this)
            % Initialize landmarks table with empty data
            
            if ~this.hasImage || ~this.hasConfig
                return;
            end
            
            c = repmat({zeros(0,2)}, this.vidSize(3), 1);
            
            this.landmarks = [];
            for i = numel(this.objNames) : -1 : 1
                tb = table(c, 'VariableNames', this.objNames(i));
                this.landmarks{i} = MLandmarkerObject(tb);
            end
            
            this.currentObject = 1;
            this.currentPoint = 1;
            
            this.landmarks2 = [];
            
            this.Refresh();
            disp('Landmarks initialized');
        end
        
        function LoadLandmarks(this)
            % Load landmark data
            
            lmPath = MBrowse.File([], 'Please select a landmarks file');
            
            if ~exist(lmPath, 'file')
                return;
            end
            
            try
                load(lmPath, '-mat');
                
                this.objNames = landmarksTable.Properties.VariableNames;
                this.landmarks = [];
                for i = numel(this.objNames) : -1 : 1
                    this.landmarks{i} = MLandmarkerObject(landmarksTable(:,i));
                end
                
                this.currentObject = 1;
                this.currentPoint = 1;
                
                set(this.handles.objectListbox, 'String', this.objNames);
                set(this.handles.objectListbox, 'Value', this.currentObject);
                this.Refresh();
                
                disp('Landmarks loaded');
            catch e
                disp(e);
            end
        end
        
        function LoadLandmarks2(this)
            % Load landmark data for comparison
            
            lmPath = MBrowse.File();
            
            if ~exist(lmPath, 'file')
                return;
            end
            
            try
                load(lmPath, '-mat');
                
                this.landmarks2 = [];
                for i = width(landmarksTable) : -1 : 1
                    this.landmarks2{i} = MLandmarkerObject(landmarksTable(:,i));
                end
                
                this.isCompare = 1;
                set(this.handles.compareCheckbox, 'Value', this.isCompare);
                this.Refresh();
                
                disp('Landmarks loaded for comparison');
            catch e
                disp(e);
            end
        end
        
        function SaveLandmarks(this)
            % 
            
            if ~this.hasLandmarks
                uiwait(msgbox('No landmark data to save.', 'Save', 'modal'));
                return;
            end
            
            landmarksTable = cellfun(@(x) x.tb, this.landmarks, 'Uni', false);
            landmarksTable = cat(2, landmarksTable{:});
            save([this.vidName, ' landmarks.mat'], 'landmarksTable');
            
            uiwait(msgbox('Landmark data is successfully saved.', 'Save', 'modal'));
        end
        
        function SaveFigure(this)
            fileName = 'img';
            imwrite(frame2im(getframe(this.handles.imgAxes)), [ fileName '.tif' ]);
        end
        
        function SetCurrentFrame(this, frIdx)
            
            if ~this.hasImage
                return;
            end
            
            targetFrame = MMath.Bound(frIdx, [1, this.vid.imgSize(3)]);
            
            if targetFrame ~= this.currentFrame
                this.currentFrame = targetFrame;
                this.Refresh();
            end
        end
        
        function SetCurrentObject(this, objIdx)
            
            if ~this.hasConfig
                return;
            end
            
            this.currentObject = objIdx;
            
            this.Refresh();
        end
        
        function SetPoint(this, ~, ~)
            % Place a point on image
            
            if ~this.hasLandmarks || this.isEnable == 0
                return;
            end
            
            mousePos = get(this.handles.imgAxes, 'CurrentPoint');
            if this.landmarks{this.currentObject}.SetPoint(this.currentFrame, this.currentPoint, mousePos([1 3]));
                this.ShowLandmarks(1);
            end
        end
        
        function DeleteLastPoint(this)
            
            if ~this.hasLandmarks || this.isEnable == 0
                return;
            end
            
            if this.landmarks{this.currentObject}.ClearLastPoint(this.currentFrame)
                this.ShowLandmarks();
            end
        end
        
        function DeleteAllPoints(this)
            
            if ~this.hasLandmarks || this.isEnable == 0
                return;
            end
            
            if this.landmarks{this.currentObject}.ClearAllPoint(this.currentFrame)
                this.ShowLandmarks();
            end
        end
        
        function GenratePoints(this)
            
            if ~this.hasLandmarks || this.isEnable == 0
                return;
            end
            
            if this.landmarks{this.currentObject}.GeneratePoints(this.currentFrame);
                this.currentPoint = this.landmarks{this.currentObject}.GetNextPointIndex(this.currentFrame);
                this.ShowLandmarks();
            end
        end
        
        function Refresh(this)
            if this.hasImage
                this.ShowFrame();
            end
            if this.hasLandmarks
                this.ShowLandmarks();
            end
            if this.hasImage || this.hasLandmarks
                pause(0.02);
            end
        end
        
        function ShowFrame(this)
            if isempty(this.handleImage)
                axes(this.handles.imgAxes);
                this.handleImage = imagesc(this.GetFrame());
                colormap gray
                axis ij equal tight
                hold on;
                
                set(this.handleImage, 'ButtonDownFcn', @this.SetPoint);
            else
                set(this.handleImage, 'CData', this.GetFrame());
            end
            set(this.handles.frameEdit, 'String', num2str(this.currentFrame));
        end
        
        function ShowLandmarks(this, incPoint)
            
            if nargin < 2
                incPoint = [];
            end
            
            % Update plot
            cellfun(@delete, this.handleLandmarks);
            this.handleLandmarks = cell(length(this.landmarks), 2);
            
            cellfun(@delete, this.handleLandmarks2);
            this.handleLandmarks2 = cell(length(this.landmarks2), 2);
            
            if this.isCompare && this.hasLandmarks2
                for i = length(this.landmarks2) : -1 : 1
                    coor = this.landmarks2{i}.GetCoordinates(this.currentFrame);
                    if isempty(coor)
                        continue;
                    end
                    
                    if i == this.currentObject
                        cc = 'y';
                    else
                        cc = 'b';
                    end
                    
                    if this.isShowNumber
                        this.handleLandmarks2{i,2} = text( ...
                            coor(:,1)+5, coor(:,2)-2.5, arrayfun(@num2str, 1:size(coor,1), 'Uni', false)', ...
                            'Color', cc, 'FontSize', 8);
                    end
                    
                    this.handleLandmarks2{i,1} = plot(this.handles.imgAxes, ...
                        coor(:,1), coor(:,2), 'o', ...
                        'Color', cc, 'LineWidth', 1);
                end
            end
            
            for i = length(this.landmarks) : -1 : 1
                coor = this.landmarks{i}.GetCoordinates(this.currentFrame);
                if isempty(coor)
                    continue;
                end
                
                if i == this.currentObject
                    cc = 'r';
                else
                    cc = 'b';
                end
                
                if this.isShowNumber
                    this.handleLandmarks{i,2} = text( ...
                        coor(:,1)+5, coor(:,2)+2.5, arrayfun(@num2str, 1:size(coor,1), 'Uni', false)', ...
                        'Color', cc, 'FontSize', 8);
                end
                
                this.handleLandmarks{i,1} = plot(this.handles.imgAxes, ...
                    coor(:,1), coor(:,2), 'x', ...
                    'Color', cc, 'LineWidth', 2);
            end
            
            % Update controls
            ptList = this.landmarks{this.currentObject}.GetPointList(this.currentFrame);
            maxPts = this.landmarks{this.currentObject}.maxNumPoints;
            nextPt = this.landmarks{this.currentObject}.GetNextPointIndex(this.currentFrame);
            
            if isempty(incPoint)
                this.currentPoint = nextPt;
            else
                this.currentPoint = this.currentPoint + incPoint;
            end
            
            set(this.handles.pointNumText, 'String', ['/ ' num2str(maxPts) ' points']);
            set(this.handles.pointPopmenu, 'String', ptList);
            set(this.handles.pointPopmenu, 'Value', this.currentPoint);
            set(this.handles.objectListbox, 'Value', this.currentObject);
        end
        
        function ShowProfile(this)
            
            if ~this.hasLandmarks
                return;
            end
            
            this.landmarks{this.currentObject}.ShowProfile();
        end
        
        function delete(this)
            % Clear up objects
            if isa(this.vid, 'TiffNow')
                delete(this.vid);
                pause(0.5);
            end
        end
    end
    
    methods(Access = private)
        % Private getters
        function img = GetFrame(this, frIdx)
            if nargin < 2
                frIdx = this.currentFrame;
            end
            img = this.vid.img(':',':',frIdx);
        end
    end
    
end

