function WriteDICOMDose(varargin)
% WriteDICOMDose saves the provided dose array to a DICOM RTDOSE file. If
% DICOM header information is provided in the third input argument, it will
% be used to populate the DICOM header for associating the DICOM RTDOSE
% file with an image set.
%
% The following variables are required for proper execution: 
%   varargin{1}: structure containing the calculated dose. Must contain
%       start, width, and data fields. See CalcDose for more information on 
%       the format of this object.
%   varargin{2}: string containing the path and name to write the DICOM 
%       RTDOSE file to. MATLAB must have write access to this location to 
%       execute successfully.
%   varargin{3} (optional): structure containing the following DICOM header
%       fields: patientName, patientID, patientBirthDate, patientSex, 
%       patientAge, classUID, studyUID, seriesUID, frameRefUID, 
%       instanceUIDs, and seriesDescription. Note, not all fields must be
%       provided.
%
% Copyright (C) 2014 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

% Run in try-catch to log error via Event.m
try
    
% Log start of DVH computation and start timer
Event(['Writing dose to DICOM RTDOSE file ', varargin{2}]);
tic;

% Initialize dicominfo structure with FileMetaInformationVersion
info.FileMetaInformationVersion = [0;1];

% Specify transfer syntax and implementation UIDs
info.TransferSyntaxUID = '1.2.840.10008.1.2';
info.ImplementationClassUID = '1.2.40.0.13.1.1';
info.ImplementationVersionName = 'dcm4che-2.0';
info.SpecificCharacterSet = 'ISO_IR 100';

% Specify class UID as RTDOSE
info.MediaStorageSOPClassUID = '1.2.840.10008.5.1.4.1.1.481.2';
info.SOPClassUID = info.MediaStorageSOPClassUID;
info.Modality = 'RTDOSE';

% Generate and specify unique instance ID
info.MediaStorageSOPInstanceUID = dicomuid;
info.SOPInstanceUID = info.MediaStorageSOPInstanceUID;
Event(['SOPInstanceUID set to ', info.SOPInstanceUID]);

% Generate creation date/time
t = now;

% Specify creation date/time
info.InstanceCreationDate = datestr(t, 'yyyymmdd');
info.InstanceCreationTime = datestr(t, 'HHMMSS');

% Specify acquisition date/time
info.AcquisitionDate = datestr(t, 'yyyymmdd');
info.AcquisitionTime = datestr(t, 'HHMMSS');

% Specifty image type
info.ImageType = 'ORIGINAL/PRIMARY/AXIAL';

% Specify manufacturer, model, and software version
info.Manufacturer = ['MATLAB ', version];
info.ManufacturerModelName = 'WriteDICOMDose';
info.SoftwareVersion = ['WriteDICOMDose (1.0) ', version];

% Specify series description (optional)
if nargin == 3 && isfield(varargin{3}, 'seriesDescription')
    info.SeriesDescription = varargin{3}.seriesDescription;
else
    info.SeriesDescription = '';
end

% Specify referenced image sequences (optional)
if nargin == 3 && isfield(varargin{3}, 'instanceUIDs') && ...
        isfield(varargin{3}, 'classUID')
    
    % Loop through instance UIDs
    for i = 1:length(varargin{3}.instanceUIDs)
        
        % Add reference image class
        info.ReferencedImageSequence.(...
            sprintf('Item_%i', i)).ReferencedSOPClassUID = ...
            varargin{3}.classUID;
        
        % Add reference image UID
        info.ReferencedImageSequence.(...
            sprintf('Item_%i', i)).ReferencedSOPInstanceUID = ...
            varargin{3}.instanceUIDs{i};
    end
end

% Specify patient info (assume that if name isn't provided, nothing is
% provided)
if nargin == 3 && isfield(varargin{3}, 'patientName')
    
    % If name is a structure
    if isstruct(varargin{3}.patientName)
        
        % Add name from provided dicominfo
        info.PatientName = varargin{3}.patientName;
        
    % Otherwise, if name is a char array
    elseif ischar(varargin{3}.patientName)
        
        % Add name to family name
        info.PatientName.FamilyName = varargin{3}.patientName;
    
    % Otherwise, throw an error
    else
        Event('Provided patient name is an unknown format', 'ERROR');
    end
    
    % Specify patient ID
    if isfield(varargin{3}, 'patientID')
        info.PatientID = varargin{3}.patientID;
    else
        info.PatientID = '';
    end
    
    % Specify patient birthdate
    if isfield(varargin{3}, 'patientBirthDate')
        info.PatientBirthDate = varargin{3}.patientBirthDate;
    else
        info.PatientBirthDate = '';
    end
    
    % Specify patient sex
    if isfield(varargin{3}, 'patientSex')
        info.PatientSex = varargin{3}.patientSex;
    else
        info.PatientSex = '';
    end
    
    % Specify patient age
    if isfield(varargin{3}, 'patientAge')
        info.PatientAge = varargin{3}.patientAge;
    else
        info.PatientAge = '';
    end
else
    % Prompt user for patient name
    input = inputdlg({'Family Name', 'Given Name', 'ID', 'Birth Date', ...
        'Sex', 'Age'}, 'Provide Patient Demographics', ...
        [1 50; 1 50; 1 30; 1 30; 1 10; 1 10]); 
    
    % Add provided input
    info.PatientName.FamilyName = char(input{1});
    info.PatientName.GivenName = char(input{2});
    info.PatientID = char(input{3});
    info.PatientBirthDate = char(input{4});
    info.PatientSex = char(input{5});
    info.PatientAge = char(input{6});
    
    % Clear temporary variables
    clear input;
end
    
% Specify slice thickness (in mm)
info.SliceThickness = varargin{1}.width(3) * 10; % mm

% Specify study UID
if nargin == 3 && isfield(varargin{3}, 'studyUID')
    info.StudyInstanceUID = varargin{3}.studyUID;
else
    info.StudyInstanceUID = '';
end

% Specify series UID
if nargin == 3 && isfield(varargin{3}, 'seriesUID')
    info.SeriesInstanceUID = varargin{3}.seriesUID;
else
    info.SeriesInstanceUID = '';
end

% Specify image position (in mm)
info.ImagePositionPatient = varargin{1}.start' * 10; % mm

% Specify frame of reference UID
if nargin == 3 && isfield(varargin{3}, 'frameRefUID')
    info.FrameOfReferenceUID = varargin{3}.frameRefUID;
else
    info.FrameOfReferenceUID = '';
end

% Specify number of images
info.ImagesInAcquisition = 1;

% Specify number of samples
info.SamplesPerPixel = 1;
info.PhotometricInterpretation = 'MONOCHROME2';

% Specify slice location (in mm)
info.SliceLocation = -varargin{1}.start(3) * 10; % mm

% Specify number of frames and grid frame offset vector (in mm)
info.NumberOfFrames = size(varargin{1}.data, 3);
info.GridFrameOffsetVector = 0:size(varargin{1}.data, 3)-1 * ...
    -varargin{1}.width * 10; % mm

% Specify number of rows/columns
info.Rows = size(varargin{1}.data, 1);
info.Columns = size(varargin{1}.data, 2);

% Specify pixel spacing (in mm)
info.PixelSpacing = [varargin{1}.width(1); varargin{1}.width(2)]; % mm

% Specify bit information
info.BitsAllocated = 16;
info.BitsStored = 16;
info.HighBit = 15;
info.PixelRepresentation = 0;

% Specify dose information
info.DoseUnits = 'Gy';
info.DoseType = 'PHYSICAL';
info.TissueHeterogeneityCorrection = 'ROI_OVERRIDE';

% Compute and specify dose scaling factor
info.DoseGridScaling = max(max(max(varargin{1}.data))) / 65535;

% Write DICOM file using dicomwrite()
dicomwrite(uint16(varargin{1}.data/info.DoseGridScaling), ...
    varargin{2}, info, 'CompressionMode', 'None', 'CreateMode', 'Copy', ...
    'Endian', 'Little', 'MultiframeSingleFile', true);

% Log completion of function
Event(sprintf(['DICOM RTDOSE export completed successfully in ', ...
    '%0.3f seconds'], toc));

% Clear temporary variables
clear info t i;

% Catch errors, log, and rethrow
catch err
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end


