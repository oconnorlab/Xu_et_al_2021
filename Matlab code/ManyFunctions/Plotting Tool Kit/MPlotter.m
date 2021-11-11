classdef MPlotter < handle
    %MPlotter Summary of this class goes here
    %   
    % Available info in ax object
    %   ax.UserData.trialNum
    %   ax.UserData.time
    %   ax.UserData.timeLimits
    %   ax.UserData.zoom
    
    properties
        defaultTimeChange = 0.005;
        defaultTrialChange = 1;
        defaultZoomChange = 1;
        zoom = 0;
        plotTable;
        callbackTable;
    end
    
    properties(Access = private)
        gui;
    end
    
    methods
        function this = MPlotter()
            % Constructor of MPlotter
            
            % Initialize tables
            this.ResetPlotTable();
            this.ResetCallbackTable();
            
            % Open GUI
            this.GUI();
        end
        
        function ResetPlotTable(this)
            columnNames = {'figureNumber', 'figureObj', 'subplot', 'axesObj', 'functionHandle', 'variableName', 'updateOption'};
            exampleRows = { ...
                1, [], '3,1,1', [], @MPlotter.PlotTimeIndicator, '', 'time'; ...
                1, [], '3,1,2:3', [], @MPlotter.PlotTimeIndicator, '', 'trial'};
            this.plotTable = cell2table(exampleRows, 'VariableNames', columnNames);
        end
        
        function ResetCallbackTable(this)
            columnNames = {'functionHandle', 'variableName', 'callbackOption', 'updateOption'};
            exampleRows = { ...
                [], '', 'keypress', 'time'; ...
                [], '', 'keyrelease', 'trial'};
            this.callbackTable = cell2table(exampleRows, 'VariableNames', columnNames);
        end
        
        function GUI(this)
            % Open GUI to add, modify and control plots
            
            % Close existing GUI
            try
                close(this.gui.fig);
                this.gui = [];
            catch
            end
            
            % Window
            wh = 130; ww = 500;
            uh = 20; uw = 60;
            s = 5;
            
            this.gui.fig = figure(...
                'Name', 'MSessionPlotter', ...
                'NumberTitle', 'off', ...
                'IntegerHandle', 'off', ...
                'MenuBar', 'none', ...
                'Resize', 'off', ...
                'WindowKeyPressFcn', @this.KeyPress, ...
                'WindowKeyReleaseFcn', @this.KeyRelease, ...
                'CloseRequestFcn', @this.CloseRequest, ...
                'Interruptible', 'off', ...
                'BusyAction', 'cancel');
            
            figPos = get(this.gui.fig, 'Position');
            set(this.gui.fig, 'Position', [figPos(1:2) ww wh]);
            
            % Trial
            x = s; y = s;
            uicontrol(this.gui.fig, ...
                'Style', 'text', ...
                'String', 'Trial #  ', ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixel', ...
                'Position', [x y-2 45 uh]);
            x = x + 45;
            
            this.gui.trialEdit = uicontrol(this.gui.fig, ...
                'Style', 'edit', ...
                'String', '1', ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixel', ...
                'Position', [x y 45 uh], ...
                'KeyReleaseFcn', @this.TrialEditChange, ...
                'Interruptible', 'off', ...
                'BusyAction', 'cancel');
            x = x + 45;
            
            % Time
            x = x + 10;
            uicontrol(this.gui.fig, ...
                'Style', 'text', ...
                'String', 'Time  ', ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixel', ...
                'Position', [x y-2 40 uh]);
            x = x + 40;
            
            this.gui.timeEdit = uicontrol(this.gui.fig, ...
                'Style', 'edit', ...
                'String', '0', ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixel', ...
                'Position', [x y 60 uh], ...
                'KeyReleaseFcn', @this.TimeEditChange, ...
                'Interruptible', 'off', ...
                'BusyAction', 'cancel');
            x = x + 60;
            
            % Limits
            x = x + 15;
            uicontrol(this.gui.fig, ...
                'Style', 'text', ...
                'String', 'Limits  ', ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixel', ...
                'Position', [x y-2 40 uh]);
            x = x + 40;
            
            this.gui.limitEdit1 = uicontrol(this.gui.fig, ...
                'Style', 'edit', ...
                'String', '0', ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixel', ...
                'Position', [x y 60 uh], ...
                'KeyReleaseFcn', @this.LimitEditChange, ...
                'Interruptible', 'off', ...
                'BusyAction', 'cancel');
            x = x + 60;
            
            this.gui.limitEdit2 = uicontrol(this.gui.fig, ...
                'Style', 'edit', ...
                'String', '1', ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixel', ...
                'Position', [x y 60 uh], ...
                'KeyReleaseFcn', @this.LimitEditChange, ...
                'Interruptible', 'off', ...
                'BusyAction', 'cancel');
            x = x + 60;
            
            % Refresh
            x = x + 15;
            uicontrol(this.gui.fig, ...
                'Style', 'pushbutton', ...
                'String', 'Refresh all', ...
                'FontSize', 9, ...
                'Units', 'pixel', ...
                'Position', [x y-1 100 uh+2], ...
                'Callback', @this.UpdateRoutine, ...
                'Interruptible', 'off', ...
                'BusyAction', 'cancel');
            x = x + 80;
            
            % Note
            x = 0;
            y = y + uh + s;
            
            noteStr = [ ...
                "Shortcuts"; ...
                "*  Left arrow: go backward in time"; ...
                "*  Right arrow: go forward in time"; ...
                "*  Up arrow: decrease trial number"; ...
                "*  Down arrow: increase trial number"; ...
                ];
            
            uicontrol(this.gui.fig, ...
                'Style', 'text', ...
                'String', arrayfun(@sprintf, noteStr, 'Uni', false), ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixel', ...
                'Position', [x+2*s y ww/2-2*s wh-s-y]);
            
            noteStr = [ ...
                "Modifiers"; ...
                "*  None: 5 ms or 1 trial"; ...
                "*  Alt: 1 ms";
                "*  Ctrl: 25 ms or 2 trial"; ...
                "*  Shift: 100 ms or 10 trial"; ...
                "*  Ctrl + Shift: 500 ms or 20 trial"; ...
                ];
            
            x = ww/2;
            uicontrol(this.gui.fig, ...
                'Style', 'text', ...
                'String', noteStr, ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixel', ...
                'Position', [x y ww/2-2*s wh-s-y]);
            y = wh-uh;
            
            % Update GUI
            this.UpdateRoutine();
            
            % Show instruction
%             eval('help MImgBaseClass.Viewer');
        end
        
        function vidMat = MakeVideo(this, h, dTime, varargin)
            % 
            
            % Handle user inputs
            p = inputParser();
            p.addParameter('filePath', [], @ischar);
            p.addParameter('frameRate', [], @isscalar);
            p.parse(varargin{:});
            filePath = p.Results.filePath;
            frRate = p.Results.frameRate;
            
            % Get variables
            timeLims(1) = str2double(this.gui.limitEdit1.String);
            timeLims(2) = str2double(this.gui.limitEdit2.String);
            
            % Capture frames
            tFr = timeLims(1) : dTime : timeLims(2);
            numFr = numel(tFr);
            vidMat(numFr) = struct('cdata', [], 'colormap', []);
            
            for k = 1 : numFr
                this.UpdateRoutine('time', tFr(k));
                drawnow;
                vidMat(k) = getframe(h);
            end
            
            vidMat = cat(4, vidMat.cdata);
            
            % Output video
            if ~isempty(filePath) && ~isempty(frRate)
                vidObj = VideoWriter(filePath);
                vidObj.Quality = 95;
                vidObj.FrameRate = frRate;
                
                open(vidObj);
                try
                    writeVideo(vidObj, vidMat);
                catch
                    close(vidObj);
                end
                close(vidObj);
            end
        end
    end
    
    methods(Access = private)
        function IntializeLayout(this)
            % Create figures and axes according to plotTable
            
            isNewFig = false;
            
            for i = 1 : height(this.plotTable)
                
                % Unload variables
                figNum = this.plotTable.figureNumber(i);
                figObj = this.plotTable.figureObj{i};
                sp = this.plotTable.subplot{i};
                sp = eval(['{' sp '}']);
                axesObj = this.plotTable.axesObj{i};
                funcHandle = this.plotTable.functionHandle{i};
                varName = this.plotTable.variableName{i};
                
                % Make figure if not exsiting
                if isempty(figObj) || ~ishandle(figObj) || ~isvalid(figObj)
                    this.plotTable.figureObj{i} = figure(figNum);
                    isNewFig = true;
                end
                
                % Make axes if not exsiting
                if isempty(axesObj) || ~ishandle(axesObj) || ~isvalid(axesObj)
                    this.plotTable.axesObj{i} = subplot(sp{:}, 'Parent', figNum);
                end
            end
            
            % Trun focus back to main window
            if isNewFig
                figure(this.gui.fig);
            end
        end
        
        function ui = GetUIVars(this)
            ui.trialNum = str2double(this.gui.trialEdit.String);
            ui.time = str2double(this.gui.timeEdit.String);
            ui.timeLims(1) = str2double(this.gui.limitEdit1.String);
            ui.timeLims(2) = str2double(this.gui.limitEdit2.String);
        end
        
        function UpdateRoutine(this, updateType, newVal)
            
            if nargin < 2
                updateType = 'trial';
            end
            
            % Apply new value to UI
            if nargin > 2
                switch updateType
                    case 'time'
                        this.gui.timeEdit.String = num2str(newVal);
                    case 'trial'
                        this.gui.trialEdit.String = num2str(newVal);
                end
            end
            
            % Get variables from control panel
            ui = this.GetUIVars();
            
            % Make figures and axes if not present
            this.IntializeLayout();
            
            % Iterate through plots
            for i = 1 : height(this.plotTable)
                
                % Unpack plotting variables
                axObj = this.plotTable.axesObj{i};
                axObj.UserData.trialNum = ui.trialNum;
                axObj.UserData.time = ui.time;
                axObj.UserData.zoom = this.zoom;
                
                if ~isnan(ui.timeLims(1))
                    axObj.UserData.timeLimits(1) = ui.timeLims(1);
                else
                    ui.timeLims(1) = axObj.UserData.timeLimits(1);
                    this.gui.limitEdit1.String = num2str(ui.timeLims(1));
                end
                if ~isnan(ui.timeLims(2))
                    axObj.UserData.timeLimits(2) = ui.timeLims(2);
                else
                    ui.timeLims(2) = axObj.UserData.timeLimits(2);
                    this.gui.limitEdit2.String = num2str(ui.timeLims(2));
                end
                
                varName = this.plotTable.variableName{i};
                funcHandle = this.plotTable.functionHandle{i};
                updateOption = this.plotTable.updateOption{i};
                
                % Check the need for update
                switch updateOption
                    case 'time'
                        % always update
                    case 'trial'
                        if strcmp(updateType, {'time'})
                            continue;
                        end
                    case 'manual'
                        if any(strcmp(updateType, {'time', 'trial'}))
                            continue;
                        end
                    otherwise
                        continue;
                end
                
                % Run function
                if isempty(varName)
                    funcHandle(axObj);
                else
                    funcHandle(axObj, evalin('base', varName));
                end
            end
        end
        
        function CallbackRoutine(this, ui, eventName)
            
            % Execute user callbacks
            for i = 1 : height(this.callbackTable)
                % Unpack variables
                funcHandle = this.callbackTable.functionHandle{i};
                varName = this.callbackTable.variableName{i};
                callbackOption = this.callbackTable.callbackOption{i};
                updateOption = this.callbackTable.updateOption{i};
                if ~strcmpi(callbackOption, eventName) || ~isa(funcHandle, 'function_handle')
                    continue;
                end
                
                % Run function
                if isempty(varName)
                    isHit = funcHandle(ui);
                else
                    isHit = funcHandle(ui, evalin('base', varName));
                end
                
                % Update UI
                if ~isempty(updateOption) && isHit
                    this.UpdateRoutine(updateOption, ui.time);
                    pause(0.05)
                end
            end
        end
        
        function KeyPress(this, src, eventdata)
            
            % Get variables from control panel
            ui = this.GetUIVars();
            ui.src = src;
            ui.eventdata = eventdata;
            
            % Execute user callbacks
            this.CallbackRoutine(ui, 'keypress');
            
            % Execute built-in callbacks
            dTrial = this.defaultTrialChange;
            dTime = this.defaultTimeChange;
            if ismember(eventdata.Modifier, {'alt', 'option'})
                dTime = dTime / 5;
            end
            if ismember('control', eventdata.Modifier)
                dTrial = dTrial * 2;
                dTime = dTime * 5;
            end
            if ismember('shift', eventdata.Modifier)
                dTrial = dTrial * 10;
                dTime = dTime * 20;
            end
%             disp(eventdata.Modifier);
            
            isUpdateUI = true;
            switch eventdata.Key
                case 'rightarrow'
                    this.UpdateRoutine('time', ui.time + dTime);
                case 'leftarrow'
                    this.UpdateRoutine('time', ui.time - dTime);
                case 'downarrow'
                    this.UpdateRoutine('trial', ui.trialNum + dTrial);
                case 'uparrow'
                    this.UpdateRoutine('trial', ui.trialNum - dTrial);
                case {'equal', 'add'}
                    this.zoom = this.zoom + 1;
                    this.UpdateRoutine('time');
%                     fprintf('Zoom %i\n', this.zoom);
                case {'hyphen', 'subtract'}
                    this.zoom = this.zoom - 1;
                    this.UpdateRoutine('time');
%                     fprintf('Zoom %i\n', this.zoom);
                case 'period'
                    this.zoom = 0;
                    this.UpdateRoutine('time');
%                     fprintf('Zoom %i\n', this.zoom);
                case 'r'
                    this.UpdateRoutine('manual');
                otherwise
%                     disp(eventdata.Key);
                    isUpdateUI = false;
            end
            if isUpdateUI
                pause(0.05)
            end
        end
        
        function KeyRelease(this, src, eventdata)
            
            % Get variables from control panel
            ui = this.GetUIVars();
            ui.src = src;
            ui.eventdata = eventdata;
            
            % Execute user callbacks
            this.CallbackRoutine(ui, 'keyrelease');
            
            % Execute built-in callbacks
            % none
        end
        
        function TrialEditChange(this, src, eventdata)
            if strcmp(eventdata.Key, 'return')
                this.UpdateRoutine('trial', str2double(src.String));
            end
        end
        
        function TimeEditChange(this, src, eventdata)
            if strcmp(eventdata.Key, 'return')
                this.UpdateRoutine('time', str2double(src.String));
            end
        end
        
        function LimitEditChange(this, src, eventdata)
            if strcmp(eventdata.Key, 'return')
                this.UpdateRoutine('time');
            end
        end
        
        function CloseRequest(this, src, eventdata)
            for i = 1 : height(this.plotTable)
                try
                    delete(this.plotTable.figureObj{i});
                catch
                end
            end
            delete(gcf);
        end
    end
    
    methods(Static)
        function PlotTimeIndicator(ax, inputVar)
            
            tr = ax.UserData.trialNum;
            t = ax.UserData.time;
            tLims = ax.UserData.timeLimits;
            z = 2^(-ax.UserData.zoom);
            
            if isfield(ax.UserData, 'indicatorObj') && ~isempty(ax.UserData.indicatorObj) && ishandle(ax.UserData.indicatorObj)
                ax.UserData.indicatorObj.XData = [t t]';
                ax.UserData.indicatorObj.YData = ax.YLim';
            else
                ax.UserData.indicatorObj = plot(ax, [t t]', ax.YLim', 'LineWidth', 2, 'Color', [0 0 0 .2]);
                hold(ax, 'on');
            end
            
            ax.XLim = tLims;
        end
    end
    
    % Hide methods from handle class
    methods(Hidden)
        function addlistener(this)
        end
        function notify(this)
        end
        function findobj(this)
        end
        function findprop(this)
        end
    end
end


