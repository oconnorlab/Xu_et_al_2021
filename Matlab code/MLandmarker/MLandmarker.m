function varargout = MLandmarker(varargin)
% MLANDMARKER MATLAB code for MLandmarker.fig
%      MLANDMARKER, by itself, creates a new MLANDMARKER or raises the existing
%      singleton*.
%
%      H = MLANDMARKER returns the handle to a new MLANDMARKER or the handle to
%      the existing singleton*.
%
%      MLANDMARKER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MLANDMARKER.M with the given input arguments.
%
%      MLANDMARKER('Property','Value',...) creates a new MLANDMARKER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MLandmarker_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MLandmarker_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MLandmarker

% Last Modified by GUIDE v2.5 18-Dec-2017 18:10:06

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MLandmarker_OpeningFcn, ...
                   'gui_OutputFcn',  @MLandmarker_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before MLandmarker is made visible.
function MLandmarker_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MLandmarker (see VARARGIN)

% Choose default command line output for MLandmarker
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes MLandmarker wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% Initialize new view-model
vm = MLandmarkerVM(handles);
setappdata(handles.output, 'vm', vm);


% --- Outputs from this function are returned to the command line.
function varargout = MLandmarker_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on key press with focus on figure1 or any of its controls.
function figure1_WindowKeyPressFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)
GlobalKeyPress(handles, eventdata);


% --- Executes on scroll wheel click while the figure is in focus.
function figure1_WindowScrollWheelFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	VerticalScrollCount: signed integer indicating direction and number of clicks
%	VerticalScrollAmount: number of lines scrolled for each click
% handles    structure with handles and user data (see GUIDATA)
GlobalKeyPress(handles, eventdata);


% --- Executes on key release with focus on figure1 or any of its controls.
function figure1_WindowKeyReleaseFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was released, in lower case
%	Character: character interpretation of the key(s) that was released
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) released
% handles    structure with handles and user data (see GUIDATA)
GlobalKeyRelease(handles, eventdata);


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
try
    vm = getappdata(handles.output, 'vm');
    delete(vm);
catch
end

% Hint: delete(hObject) closes the figure
delete(hObject);


function frameEdit_Callback(hObject, eventdata, handles)
% hObject    handle to frameEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of frameEdit as text
%        str2double(get(hObject,'String')) returns contents of frameEdit as a double
vm = getappdata(handles.output, 'vm');
vm.SetCurrentFrame(str2double(get(hObject, 'String')));
set(hObject, 'String', vm.currentFrame);


% --- Executes during object creation, after setting all properties.
function frameEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to frameEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% Handles the global key press
function GlobalKeyPress(handles, eventdata)

vm = getappdata(handles.output, 'vm');

% Keyboard inputs
if isfield(eventdata, 'Key') || isa(eventdata, 'matlab.ui.eventdata.KeyData')
    % Handles key press
    if any(strcmp(eventdata.Modifier, 'control'))
        if any(strcmp(eventdata.Modifier, 'shift'))
            frChange = 50;
        else
            frChange = 10;
        end
    else
        frChange = 1;
    end
    
    switch eventdata.Key
        case {'rightarrow', 'd'}
            vm.SetCurrentFrame(vm.currentFrame + frChange);
        case {'leftarrow', 'a'}
            vm.SetCurrentFrame(vm.currentFrame - frChange);
    end
else
    % Mouse scrolling input
    signChange = sign(eventdata.VerticalScrollCount);
    frChange = min(abs(eventdata.VerticalScrollCount), 3);
    vm.SetCurrentFrame(vm.currentFrame + signChange*frChange);
end


% Handles the global key release
function GlobalKeyRelease(handles, eventdata)

vm = getappdata(handles.output, 'vm');

% Handles key press
switch eventdata.Key
    case 'e'
        if any(strcmp(eventdata.Modifier, 'shift'))
            vm.DeleteAllPoints();
        else
            vm.DeleteLastPoint();
        end
    case 'q'
        vm.GenratePoints();
    case 's'
        if any(strcmp('control', eventdata.Modifier))
            vm.SaveLandmarks();
        end
    case 'p'
        vm.ShowProfile();
    case {'1', '2', '3'}
        if any(strcmp('control', eventdata.Modifier))
            pos = get(handles.imgAxes, 'Position');
            pos(3:4) = vm.vidSize([2 1]) * str2double(eventdata.Key);
            set(handles.imgAxes, 'Position', pos);
        end
end
pause(0.02);


% --------------------------------------------------------------------
function imageMenu_Callback(hObject, eventdata, handles)
% hObject    handle to imageMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function loadCfgMenu_Callback(hObject, eventdata, handles)
% hObject    handle to loadCfgMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function openImageMenu_Callback(hObject, eventdata, handles)
% hObject    handle to openImageMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.LoadImage();


% --------------------------------------------------------------------
function saveLandmarksMenu_Callback(hObject, eventdata, handles)
% hObject    handle to saveLandmarksMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.SaveLandmarks();


% --- Executes on button press in prevFrameButton.
function prevFrameButton_Callback(hObject, eventdata, handles)
% hObject    handle to prevFrameButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.SetCurrentFrame(vm.currentFrame - 1);


% --- Executes on button press in nextFrameButton.
function nextFrameButton_Callback(hObject, eventdata, handles)
% hObject    handle to nextFrameButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.SetCurrentFrame(vm.currentFrame + 1);


% --- Executes on selection change in objectListbox.
function objectListbox_Callback(hObject, eventdata, handles)
% hObject    handle to objectListbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns objectListbox contents as cell array
%        contents{get(hObject,'Value')} returns selected item from objectListbox
vm = getappdata(handles.output, 'vm');
vm.SetCurrentObject(get(hObject,'Value'));


% --- Executes during object creation, after setting all properties.
function objectListbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to objectListbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in deleteAllButton.
function deleteAllButton_Callback(hObject, eventdata, handles)
% hObject    handle to deleteAllButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.DeleteAllPoints();


% --- Executes on button press in deleteLastButton.
function deleteLastButton_Callback(hObject, eventdata, handles)
% hObject    handle to deleteLastButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.DeleteLastPoint();


function pointPopmenu_Callback(hObject, eventdata, handles)
% hObject    handle to pointPopmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pointPopmenu as text
%        str2double(get(hObject,'String')) returns contents of pointPopmenu as a double
vm = getappdata(handles.output, 'vm');
vm.currentPoint = get(hObject, 'Value');


% --- Executes during object creation, after setting all properties.
function pointPopmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pointPopmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function loadLandmarksMenu_Callback(hObject, eventdata, handles)
% hObject    handle to loadLandmarksMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.LoadLandmarks();


% --------------------------------------------------------------------
function newLandmarksMenu_Callback(hObject, eventdata, handles)
% hObject    handle to newLandmarksMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.LoadConfiguration();


% --- Executes on button press in enableCheckbox.
function enableCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to enableCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of enableCheckbox
vm = getappdata(handles.output, 'vm');
vm.isEnable = get(hObject, 'Value');


% --- Executes on button press in interpButton.
function interpButton_Callback(hObject, eventdata, handles)
% hObject    handle to interpButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.GenratePoints();


% --- Executes when figure1 is resized.
function figure1_ResizeFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
if vm.hasImage
    figPos = get(handles.figure1, 'Position');
    axPos = get(handles.imgAxes, 'Position');
    r = (figPos(3:4) - [250 50]) ./ vm.vidSize([2 1]);
    r = max(1, floor(min(r)));
    axPos(3:4) = vm.vidSize([2 1]) * r;
    set(handles.imgAxes, 'Position', axPos);
end


% --------------------------------------------------------------------
function landmarksMenu_Callback(hObject, eventdata, handles)
% hObject    handle to landmarksMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function drawRoiMenu_Callback(hObject, eventdata, handles)
% hObject    handle to drawRoiMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function resetRoiMenu_Callback(hObject, eventdata, handles)
% hObject    handle to resetRoiMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function compareMenu_Callback(hObject, eventdata, handles)
% hObject    handle to compareMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.LoadLandmarks2();


% --- Executes on button press in compareCheckbox.
function compareCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to compareCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of compareCheckbox
vm = getappdata(handles.output, 'vm');
vm.isCompare = get(hObject, 'Value');
vm.Refresh();


% --- Executes on button press in profileButton.
function profileButton_Callback(hObject, eventdata, handles)
% hObject    handle to profileButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.ShowProfile();


% --- Executes on button press in numberCheckbox.
function numberCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to numberCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of numberCheckbox
vm = getappdata(handles.output, 'vm');
vm.isShowNumber = get(hObject, 'Value');
vm.ShowLandmarks(0);
