guidfunction varargout = ColdAtomsControlGui(varargin)
% COLDATOMSCONTROLGUI MATLAB code for ColdAtomsControlGui.fig
%      COLDATOMSCONTROLGUI, by itself, creates a new COLDATOMSCONTROLGUI or raises the existing
%      singleton*.
%
%      H = COLDATOMSCONTROLGUI returns the handle to a new COLDATOMSCONTROLGUI or the handle to
%      the existing singleton*.
%
%      COLDATOMSCONTROLGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in COLDATOMSCONTROLGUI.M with the given input arguments.
%
%      COLDATOMSCONTROLGUI('Property','Value',...) creates a new COLDATOMSCONTROLGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ColdAtomsControlGui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ColdAtomsControlGui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ColdAtomsControlGui

% Last Modified by GUIDE v2.5 16-Dec-2016 10:51:41

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ColdAtomsControlGui_OpeningFcn, ...
                   'gui_OutputFcn',  @ColdAtomsControlGui_OutputFcn, ...
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


% --- Executes just before ColdAtomsControlGui is made visible.
function ColdAtomsControlGui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ColdAtomsControlGui (see VARARGIN)

% Choose default command line output for ColdAtomsControlGui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes ColdAtomsControlGui wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = ColdAtomsControlGui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in MOTButton.
function MOTButton_Callback(hObject, eventdata, handles)
% hObject    handle to MOTButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
prog=CodeGenerator;
pulseSeq=[Pulse('DigOut0',0,1)];
prog.GenSeq(pulseSeq);
prog.DisplayCode;
%FPGA/Host control
com=Tcp2Labview('localhost',6340);
pause(1);
com.UploadCode(prog);
com.UpdateFpga;
com.WaitForHostIdle;
com.Execute(1);  
com.Delete;


% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
prog=CodeGenerator;
pulseSeq=[Pulse('DigOut0',-1,1)];
prog.GenSeq(pulseSeq);
prog.DisplayCode;
%FPGA/Host control
com=Tcp2Labview('localhost',6340);
pause(1);
com.UploadCode(prog);
com.UpdateFpga;
com.WaitForHostIdle;
com.Execute(1);  
com.Delete;
