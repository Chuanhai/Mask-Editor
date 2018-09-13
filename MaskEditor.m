classdef MaskEditor < handle
    %% MaskEditor
    % Notes:
    % - Image Processing Toolbox is needed
    % - please report bugs and suggestions for improvement
    % This program is developed based on Jonas Reber's Multi ROI/Mask Editor Class
    % https://www.mathworks.com/matlabcentral/fileexchange/31388-multi-roi-mask-editor-class
    
    properties
        % UI stuff
        guifig       % mainwindow
        imax         % holds working area
        imag         % image to work on
        tl           % userinfo bar
        buttons      % userinfo button
        hpt
        transparency
        draw_type=0; % drawing type
        draw_num=0;  %
        penSize=1;   % paint/eraser width
        
        winPos = [0.01 0.04 0.98 0.9];
        
        
        % image status
        rawImage     % global image
        ROIimage     % ROI image
        rawMask      % global mask
        ROImask      % ROI mask
        superPixels  % super pixel matrix
        superPixelsNumber
        ROI_x_offset
        ROI_y_offset
        
        % load/save information
        filename
        pathname
        fileIndex
        files
        defectList
        
        % class information
        ObjectClasses={};
        currentClassIndex=0;
        objectColors=[0.0 1.0 0.0];
    end
    
    %% Public Methods
    methods
        
        function this = MaskEditor(theImage)
            try
                % constructor
                % invoke the UI window
                this.createWindow;
                % load the image
                if nargin > 0
                    this.rawImage = theImage;
                    this.ROIimage=theImage;
                else
                    this.rawImage = ones(100,100,3);
                    this.ROIimage=this.rawImage;
                end
                this.ROI_x_offset=0;
                this.ROI_y_offset=0;
                % predefine class variables
                this.filename = 'mymask'; % default filename
                this.pathname = [pwd '\'];      % current directory
                this.fileIndex=0;
                this.currentClassIndex=1;
                this.superPixelsNumber=0;
                this.transparency=0.5;
                % import the defect name list and show them on gui
                %             [~,~,this.defectList]=xlsread('Defects List.xlsx');
                this.defectList={'foreground' 'defect_1' 'defect_2'  'defect_3'  'defect_4'  'defect_5'  'defect_6'  'defect_7'  'defect_8'};
                
                %             for i=2:size(this.defectList,1)
                for i=2:length(this.defectList)
                    this.ObjectClasses{end+1}=this.defectList{i};
                    %this.ObjectClasses{end+1}=[num2str(this.defectList{i,1}) '_' this.defectList{i,2}];
                    if(i>2)
                        this.objectColors(end+1,:)=[0.0 1.0 0.0];
                    end
                end
                set(findobj('Tag','classList'),'String',this.ObjectClasses);
            catch
                disp('error on MaskEditor()')
            end
        end
        
        function delete(this)
            try
                % destructor
                delete(this.guifig);
            catch
                disp('error on delete()')
            end
        end
        
        function set.ROIimage(this,theImage)
            try
                % set method for image. uses grayscale images for region selection
                if size(theImage,3) == 3
                    this.ROIimage = im2double(theImage);
                elseif size(theImage,3) == 1
                    this.ROIimage = im2double(theImage);
                else
                    error('Unknown Image size?');
                end
                this.resetImages;
                this.resizeWindow;
            catch
                disp('error on set.ROIimage()')
            end
        end
    end
    
    %% private used methods
    methods(Access=private)
        % general functions -----------------------------------------------
        function resetImages(this)
            try
                % load images
                this.imag = imshow(this.ROIimage,'parent',this.imax);
                % set masks to blank
                dim=size(this.ROIimage);
                this.superPixels=zeros(dim(1:2));
                this.superPixelsNumber=0;
            catch
                disp('error on resetImages()')
            end
        end
        %% load new image to edit
        function newROI(this)
            try
                dim=size(this.rawImage);
                this.rawMask = zeros([dim(1:2) size(this.ObjectClasses,2)]);
                dim=size(this.ROIimage);
                this.ROImask = zeros([dim(1:2) size(this.ObjectClasses,2)]);
                
                this.superPixels=zeros(dim(1:2));
                this.superPixelsNumber=0;
                this.draw_type=0;
                this.draw_num=0;
                temp = get(findobj('Tag','width'),'Value');
                if(iscell(temp))
                    val = temp{1};
                else
                    val = temp;
                end
                this.penSize = ceil(val);
            catch
                disp('error on newROI()')
                % just catch the exception, no processing
            end
        end
        %% refersh the working regions of the images
        function updateROI(this)
            try
                currentMask=this.ROImask(:,:,this.currentClassIndex);
                val=max(max(currentMask));
                if val>0
                    overlay=labeloverlay(im2uint8(this.ROIimage),currentMask,'Transparency',this.transparency,...
                        'Colormap',this.objectColors(1:size(this.ObjectClasses,2),:));
                else
                    overlay=this.ROIimage;
                end
                set(this.imag,'CData',overlay);
            catch
                disp('error on updateROI()')
            end
        end
        
        % CALLBACK FUNCTIONS
        % window/figure
        function winpressed(this,h,e,~)
            try
                if(this.menu_status)
                    b = get(h,'selectiontype');
                    if(and(strcmpi(b,'normal'),this.draw_type==-1))% start erasing
                        this.draw_type=-2;
                    elseif(and(strcmpi(b,'normal'),this.draw_type==-3))% start painting
                        this.draw_type=-4;
                    end
                    
                    if(and(strcmp(e.EventName,'WindowMouseRelease'),this.draw_type==-2))
                        this.draw_type=-1;
                    elseif(and(strcmp(e.EventName,'WindowMouseRelease'),this.draw_type==-4))
                        this.draw_type=-3;
                    end
                    
                    % no response when pressing right button
                    condition=~strcmpi(b,'alt')+strcmp(e.EventName,'WindowMouseRelease')+(this.draw_num==1);
                    
                    if condition==3
                        switch this.draw_type
                            case 1
                                freeclick(this,h,e); % new free hand
                            case 2
                                elliclick(this,h,e); % new ellipse
                            case 3
                                rectclick(this,h,e); % new rectangle
                            case 4
                                superPixelSelect(this,h,e); % new point
                            case 5
                                deleteclick(this,h,e); % new point
                            otherwise
                                % just catch the exception, no processing
                        end
                    end
                end
            catch
                disp('error on winpressed()')
            end
        end
        
        function keypressed(this,h,e)
            try
                if or(strcmp(e.Key,'rightarrow'),strcmp(e.Key,'downarrow'))
                    nextImage(this,h,e);
                elseif or(strcmp(e.Key,'leftarrow'),strcmp(e.Key,'uparrow'))
                    prevImage(this,h,e);
                else
                    % do nothing
                end
            catch
                disp('error on keypressed()')
            end
        end
        
        %% Region of interest selection
        function ROIclick(this,~,~)
            try
                handle= imrect(this.imax);
                set(handle,'visible','off');
                BWadd = handle.createMask(this.imag);
                CC=regionprops(BWadd,'BoundingBox');
                pos=CC.BoundingBox;
                
                
                dim=size(this.ROIimage);
                startX=this.ROI_x_offset+max(1,ceil(pos(2)));
                endX  =this.ROI_x_offset+min(ceil(pos(2))+pos(4),dim(1));
                
                startY=this.ROI_y_offset+max(1,ceil(pos(1)));
                endY  =this.ROI_y_offset+min(ceil(pos(1)+pos(3)),dim(2));
                
                this.ROI_x_offset=startX-1;
                this.ROI_y_offset=startY-1;
                
                this.ROImask = this.rawMask(startX:endX,startY:endY,:);
                this.ROIimage = this.rawImage(startX:endX,startY:endY,:);
                
                this.updateROI;
                delete(handle);
            catch
                disp('error on ROIclick()')
            end
        end
        
        function UndoROI(this,h,e)
            try
                maskAutoSave(this,h,e,0);
                this.ROIimage=this.rawImage;
                this.ROImask=this.rawMask;
                this.ROI_x_offset=0;
                this.ROI_y_offset=0;
                this.draw_num=0;
                this.updateROI;
            catch
                disp('error on UndoROI()')
                %just catch the exception, no processing
            end
        end
        
        function [status]=menu_status(this)
            try
                b1=strcmp(get(findobj('Tag','tool_zoom_out'),'State'),'off');
                b2=strcmp(get(findobj('Tag','tool_zoom_in'),'State'),'off');
                b3=strcmp(get(findobj('Tag','tool_hand'),'State'),'off');
                status=((b1+b2+b3)==3);
            catch
                disp('error on menu_status()')
            end
        end
        
        %% ready for painting
        function paintclick(this,~,~)
            try
                if(this.menu_status)
                    this.draw_type=-3;
                end
            catch
                disp('error on paintclick()')
            end
        end
        %% ready for erasing
        function eraserclick(this,~,~)
            try
                if(this.menu_status)
                    this.draw_type=-1;
                end
            catch
                disp('error on eraserclick()')
            end
        end
        %% select a rectangle area for deleting
        function deleteclick(this,~,~)
            try
                if(this.menu_status)
                    this.draw_num=0;
                    this.draw_type=5;
                    handle= imrect(this.imax);
                    set(handle,'visible','off');
                    if(this.currentClassIndex>0)
                        BWadd = handle.createMask(this.imag);
                        currentMask=this.ROImask(:,:,this.currentClassIndex);
                        currentMask(BWadd>0)=0;
                        this.ROImask(:,:,this.currentClassIndex)=currentMask;
                        this.updateROI();
                    end
                    delete(handle);
                    this.draw_num=1;
                end
            catch
                disp('error on deleteclick()')
                % just catch the exception, no processing
            end
        end
        %% painting and erasing
        function mousemove(this,~,~,~)
            try
                if(this.menu_status)
                    if(or(this.draw_type==-2,this.draw_type==-4))
                        %                         disp('hello')
                        curr = get (gca, 'CurrentPoint');
                        handle= impoint(this.imax,curr(1,1),curr(1,2));
                        set(handle,'visible','off');
                        BWadd = handle.createMask(this.imag);
                        se = strel('disk',this.penSize*2);
                        BWadd = imdilate(BWadd,se);
                        
                        if(this.draw_type==-2)% erasing
                            currentMask=this.ROImask(:,:,this.currentClassIndex);
                            currentMask(BWadd>0)=0;
                            this.ROImask(:,:,this.currentClassIndex)=currentMask;
                        else % painting
                            currentMask=this.ROImask(:,:,this.currentClassIndex);
                            currentMask(BWadd>0)=this.currentClassIndex;
                            this.ROImask(:,:,this.currentClassIndex)=currentMask;
                        end
                        delete(handle);
                        this.updateROI; % add tag, and callback to new shape
                    end
                end
            catch
                disp('error on mousemove()')
            end
        end
        %% window close
        function closefig(this,~,~)
            try
                delete(this);
            catch
                disp('error on closefig()')
            end
        end
        %% select single or multiple images to open, currently supports *.jpg, *.bmp, *.png, *.tif images
        function openImage(this,~,~)
            try
                format='*.jpg;*.jpeg;*.bmp;*.png;*.tiff;*.tif';
                [filenames,pathName,~] = uigetfile(fullfile(pwd,format),'select image','MultiSelect', 'on');
                if(length(filenames)>=1)
                    this.pathname=[pathName '\'];
                    if(ischar(filenames))% only read one image
                        this.files={filenames};
                        this.fileIndex=1;
                        this.filename=filenames;
                    else % read multiple images
                        this.files=filenames;
                        this.fileIndex=1;
                        this.filename=this.files{1};
                    end
                    
                    this.rawImage=imread([this.pathname this.filename]);
                    set(findobj('Tag','filename'),'String',this.filename);
                    str=[num2str(this.fileIndex) ' / ' num2str(length(this.files)) '  images'];
                    set(findobj('Tag','fileIndex'),'String',str);
                    
                    this.ROIimage=this.rawImage;
                    this.ROI_x_offset=0;
                    this.ROI_y_offset=0;
                    this.newROI;
                    this.autoLoadMask;
                    this.updateROI;
                else
                    % no processing
                end
            catch
                disp('error on openImage()')
                %                 % just catch the exception, no processing
            end
        end
        
        %% load existing masks for editing
        function openMask(this,~,~)
            try
                pathName= [uigetdir '\'];
                % enumerate all possible defetc masks to laod
                for i=2:size(this.defectList,1)
                    defect_name=[num2str(this.defectList{i,1}) '_' this.defectList{i,2}];
                    full_name=[pathName this.filename(1:end-4) '_mask_' defect_name '.png'];
                    
                    if(exist(full_name, 'file'))
                        cur_defect_mask=imread(full_name);
                        if(and(size(this.rawImage,1)==size(cur_defect_mask,1),size(this.rawImage,2)==size(cur_defect_mask,2)))
                            cur_defect_mask(cur_defect_mask>0)= i-1;
                            this.rawMask(:,:,i-1)=cur_defect_mask;
                        else
                            msgbox('Mask size does not match with the orginal image!!');
                        end
                    end
                end
                %                 this.currentClassIndex = 1;
                this.ROImask = this.rawMask;
                this.updateROI;
                disp('loading mask success!!')
            catch
                disp('error on openMask()')
                % just catch the exception, no processing
            end
        end
        
        %% automatically load existing masks for the current image,
        % this function will be used in navigating to the previous or next image
        function autoLoadMask(this,~,~)
            try
                overlay_full_name=[this.pathname 'Masks\' this.filename(1:end-4) '_overlay_.jpg'];
                if(exist(overlay_full_name,'file'))
                    for i=2:length(this.defectList)
                        defect_name=this.defectList{i};
                        full_name=[this.pathname 'Masks\' this.filename(1:end-4) '_mask_' defect_name '.png'];
                        if(exist(full_name,'file'))
                            cur_defect_mask=imread(full_name);
                            if(and(size(this.rawImage,1)==size(cur_defect_mask,1),size(this.rawImage,2)==size(cur_defect_mask,2)))
                                cur_defect_mask(cur_defect_mask>0)= i-1;
                                this.rawMask(:,:,i-1)=cur_defect_mask;
                            end
                        end
                    end
                    %                     this.ROIimage=this.rawImage;
                    this.ROImask = this.rawMask;
                end
            catch
                disp('error on autoLoadMask()')
                % just catch the exception, no processing
            end
        end
        
        %% open an image folder
        function openDir(this,~,~)
            % load image files from Folder
            try
                pathName= [uigetdir '\'];
                Files=[dir([pathName '*.jpg']);dir([pathName '*.jpeg']);...
                    dir([pathName '*.bmp']);dir([pathName '*.png']);...
                    dir([pathName '*.tiff']);dir([pathName '*.tif'])];
                
                if(length(Files)>=1)
                    FileIndex=1;
                    this.files={};
                    for i=1:length(Files)
                        this.files{end+1}=Files(i).name;
                    end
                    this.pathname=pathName;
                    this.fileIndex=FileIndex;
                    this.restoreCheckPoints;
                    this.rawImage=imread([this.pathname this.filename]);
                    set(findobj('Tag','filename'),'String',this.filename);
                    str=[num2str(this.fileIndex) ' / ' num2str(length(this.files)) '  images'];
                    set(findobj('Tag','fileIndex'),'String',str);
                    
                    this.ROIimage=this.rawImage;
                    this.ROI_x_offset=0;
                    this.ROI_y_offset=0;
                    this.superPixelsNumber=0;
                    this.newROI;
                    this.autoLoadMask;
                    this.updateROI;
                end
            catch
                disp('error on openDir()')
                % just catch the exception, no processing
            end
        end
        
        %% restore from checkpoints
        function restoreCheckPoints(this)
            try
                % create checkpoint files for each defect
                if(~exist([this.pathname 'checkpoints'],'dir'))
                    mkdir(this.pathname,'checkpoints');
                end
                checkpoints=[this.pathname 'checkpoints\' this.ObjectClasses{this.currentClassIndex} '.txt'];
                if(exist(checkpoints,'file'))
                    fileID = fopen(checkpoints,'r');
                    tline = fgets(fileID);
                    fclose(fileID);
                    this.fileIndex=str2num(tline);
                else
                    fileID = fopen(checkpoints,'w');
                    fprintf(fileID,'%d \n',1);
                    fclose(fileID);
                end
                this.filename=this.files{this.fileIndex};
            catch
                disp('error on restoreCheckPoints()')
            end
        end
        
        %         %% save Mask to File
        %         function maualSaveMask(this, ~,~)
        %             try
        %                 [fileName, pathName] = uiputfile('*.png','Save Mask as',this.filename(1:end-4));
        %                 % save the mask
        %                 for i=1:size(this.ObjectClasses,2)
        %                     curMask=this.ROImask(:,:,i);
        %                     if(max(max(curMask))>0)
        %                         dim=size(curMask);
        %                         temp=this.rawMask(:,:,i);
        %                         temp(this.ROI_x_offset+1:this.ROI_x_offset+dim(1),this.ROI_y_offset+1:this.ROI_y_offset+dim(2))=curMask;
        %                         temp(temp>0)=255;
        %                         imwrite(uint8(temp),[pathName fileName(1:end-4) '_mask_' this.ObjectClasses{i} '.png']);
        %                     end
        %                 end
        %
        %                 % save the overlay
        %                 this.rawMask(this.ROI_x_offset+1:this.ROI_x_offset+dim(1),this.ROI_y_offset+1:this.ROI_y_offset+dim(2),:)=this.ROImask;
        %                 mixMask=max(this.rawMask,[],3);
        %                 overlay=labeloverlay(im2uint8(this.rawImage),mixMask,'Transparency',0.85,...
        %                     'Colormap',this.objectColors);
        %                 imwrite(overlay,[this.pathname 'Masks\' this.filename(1:end-4) '_overlay_.jpg']);
        %                 msgbox('Save Done!!');
        %             catch
        %                 % just catch the exception, no processing
        %             end
        %         end
        %% Generate super pixels for the current image
        function superPixel(this,~,~)
            try
                temp=get(findobj('Tag','superPixelNumber'),'Value');
                if(iscell(temp))
                    superPixelNumber=temp{1};
                else
                    superPixelNumber=temp;
                end
                
                temp=get(findobj('Tag','compactness'),'Value');
                if(iscell(temp))
                    compactness=temp{1};
                else
                    compactness=temp;
                end
                
                temp=get(findobj('Tag','iterNumber'),'Value');
                if(iscell(temp))
                    iterNumber=temp{1};
                else
                    iterNumber=temp;
                end
                
                [Label,Number] = superpixels(this.ROIimage,ceil(superPixelNumber),'Compactness',ceil(compactness),'NumIterations',ceil(iterNumber));
                this.superPixels=Label; this.superPixelsNumber=Number;
                BW = boundarymask(Label);
                %BW=bwmorph(BW,'skel',Inf);
                imageSeg=labeloverlay(im2uint8(this.ROIimage),BW,'Transparency',0.5);
                set(this.imag,'CData',imageSeg);
            catch
                disp('error on superPixel()')
                % just catch the exception, no processing
            end
        end
        
        %% draw the boundary of interested regions
        function freeclick(this,~,~)
            try
                if(this.menu_status)
                    this.draw_num=0;
                    this.draw_type=1;
                    
                    handle= imfreehand(this.imax);
                    set(handle,'visible','off');
                    
                    if(this.currentClassIndex>0)
                        BWadd = handle.createMask(this.imag);
                        currentMask=this.ROImask(:,:,this.currentClassIndex);
                        currentMask(BWadd>0)=this.currentClassIndex;
                        this.ROImask(:,:,this.currentClassIndex)=currentMask;
                        this.updateROI();
                    end
                    delete(handle);
                    this.draw_num=1;
                end
            catch
                disp('error on freeclick()')
                % just catch the exception, no processing
            end
        end
        
        %% ready for super pixel selection and mark
        function magicClick(this,~,~)
            try
                if(this.menu_status)
                    this.draw_type=4;
                    this.draw_num=1;
                    
                    % the following code is important when switching from "zoom in"
                    % "zoom out", and "pan"
                    handle= impoint(this.imax);
                    set(handle,'visible','off');
                    delete(handle);
                end
            catch
                disp('error on magicClick()')
            end
        end
        %% super pixel selection and mark
        function superPixelSelect(this,~,~)
            try
                if(this.menu_status)
                    curr = get (gca, 'CurrentPoint');
                    this.draw_num=0;
                    this.draw_type=4;
                    
                    handle= impoint(this.imax,curr(1,1),curr(1,2));
                    set(handle,'visible','off');
                    if(and(this.superPixelsNumber>0,this.currentClassIndex>0))
                        BWadd = handle.createMask(this.imag);
                        label=this.superPixels;
                        label(BWadd==0)=0;
                        regionIndex=max(max(label));
                        
                        currentMask=this.ROImask(:,:,this.currentClassIndex);
                        
                        temp=currentMask;
                        temp(temp>=0)=0;
                        temp(this.superPixels==regionIndex)=1;
                        temp=and(temp,currentMask);
                        
                        if(sum(sum(temp))>0)% delete super-pixel
                            currentMask(this.superPixels==regionIndex)=0;
                        else % select super-pixel
                            currentMask(this.superPixels==regionIndex)=this.currentClassIndex;
                        end
                        this.ROImask(:,:,this.currentClassIndex)=currentMask;
                    end
                    this.updateROI; % add tag, and callback to new shape
                    delete(handle);
                    this.draw_num=1;
                end
            catch
                disp('error on superPixelSelect()')
                % just catch the exception, no processing
            end
        end
        
        %% select a ellipse area for labeling
        function elliclick(this,~,~)
            try
                if(this.menu_status)
                    this.draw_num=0;
                    this.draw_type=2;
                    handle= imellipse(this.imax);
                    set(handle,'visible','off');
                    
                    if(this.currentClassIndex>0)
                        BWadd = handle.createMask(this.imag);
                        currentMask=this.ROImask(:,:,this.currentClassIndex);
                        currentMask(BWadd>0)=this.currentClassIndex;
                        this.ROImask(:,:,this.currentClassIndex)=currentMask;
                        this.updateROI();
                    end
                    delete(handle);
                    this.draw_num=1;
                end
            catch
                disp('error on elliclick()')
                % just catch the exception, no processing
            end
        end
        
        %% select a rectangle area for labeling
        function rectclick(this,~,~)
            try
                if(this.menu_status)
                    this.draw_num=0;
                    this.draw_type=3;
                    handle= imrect(this.imax);
                    set(handle,'visible','off');
                    
                    if(this.currentClassIndex>0)
                        BWadd = handle.createMask(this.imag);
                        currentMask=this.ROImask(:,:,this.currentClassIndex);
                        currentMask(BWadd>0)=this.currentClassIndex;
                        this.ROImask(:,:,this.currentClassIndex)=currentMask;
                        this.updateROI();
                    end
                    delete(handle);
                    this.draw_num=1;
                end
            catch
                disp('error on rectclick()')
                % just catch the exception, no processing
            end
        end
        
        %% select a polygon area for labeling
        function polyclick(this,~,~)
            try
                if(this.menu_status)
                    this.draw_num=0;
                    this.draw_type=4;
                    handle= impoly(this.imax);
                    set(handle,'visible','off');
                    %handle.Deletable=false;
                    
                    if(this.currentClassIndex>0)
                        BWadd = handle.createMask(this.imag);
                        currentMask=this.ROImask(:,:,this.currentClassIndex);
                        currentMask(BWadd>0)=this.currentClassIndex;
                        this.ROImask(:,:,this.currentClassIndex)=currentMask;
                        this.updateROI();
                    end
                    delete(handle);
                    this.draw_num=1;
                end
            catch
                disp('error on polyclick()')
                % just catch the exception, no processing
            end
        end
        %% save the mask
        
        function applyclick(this,h,e)
            try
                maskAutoSave(this,h,e,1);
            catch
                disp('error on applyclick()')
            end
        end
        
        function maskAutoSave(this,h,e,message)
            try
                if(~exist([this.pathname 'Masks'], 'dir'))
                    mkdir(this.pathname,'Masks');
                end
                %                 if(~exist([this.pathname 'Masks_ROI'], 'dir'))
                %                     mkdir(this.pathname,'Masks_ROI');
                %                 end
                %                 if(sum(sum(sum(this.ROImask)))>0)
                % save the mask
                dim=size(this.ROImask);
                for i=1:size(this.ObjectClasses,2)
                    curMask=this.ROImask(:,:,i);
                    cond1=exist([this.pathname 'Masks\' this.filename(1:end-4) '_mask_' this.ObjectClasses{i} '.png'],'file');
                    cond2=(max(max(curMask))>0);
                    if(and(cond1,~cond2))
                        delete([this.pathname 'Masks\' this.filename(1:end-4) '_mask_' this.ObjectClasses{i} '.png']);
                    elseif(cond2)
                        temp=this.rawMask(:,:,i);
                        temp(this.ROI_x_offset+1:this.ROI_x_offset+dim(1),this.ROI_y_offset+1:this.ROI_y_offset+dim(2))=curMask;
                        temp(temp>0)=255;
                        imwrite(uint8(temp),[this.pathname 'Masks\' this.filename(1:end-4) '_mask_' this.ObjectClasses{i} '.png']);
                        %                         imwrite(uint8(curMask*255),[this.pathname 'Masks_ROI\' this.filename(1:end-4) '_ROImask_' this.ObjectClasses{i} '.png']);
                    end
                end
                
                if(sum(sum(sum(this.ROImask)))>0)
                    % save the overlay
                    this.rawMask(this.ROI_x_offset+1:this.ROI_x_offset+dim(1),this.ROI_y_offset+1:this.ROI_y_offset+dim(2),:)=this.ROImask;
                    mixMask=max(this.rawMask,[],3);
                    overlay=labeloverlay(im2uint8(this.rawImage),mixMask,'Transparency',0.85,'Colormap',this.objectColors);
                    imwrite(overlay,[this.pathname 'Masks\' this.filename(1:end-4) '_overlay_.jpg']);
                    %                 imwrite(this.ROIimage,[this.pathname 'Masks_ROI\' this.filename]);
                end
                
                if(message==1)
                    msgbox('Save Done!!');
                end
            catch
                disp('error on maskAutoSave()')
                % just catch the exception, no processing
            end
        end
        
        %% load the previous image
        function prevImage(this,h,e)
            try
                maskAutoSave(this,h,e,0);% save the current mask before loading the next image
                if(this.fileIndex>=2)
                    this.fileIndex=this.fileIndex-1;
                    this.filename=this.files{this.fileIndex};
                    this.rawImage=imread([this.pathname this.filename]);
                    set(findobj('Tag','filename'),'String',this.filename);
                    str=[num2str(this.fileIndex) ' / ' num2str(length(this.files)) '  images'];
                    set(findobj('Tag','fileIndex'),'String',str);
                    this.ROIimage=this.rawImage;
                    this.ROI_x_offset=0;
                    this.ROI_y_offset=0;
                    this.superPixelsNumber=0;
                    this.newROI;
                    this.autoLoadMask;
                    this.updateROI;
                else
                    % just catch the exception, no processing
                end
            catch
                disp('error on prevImage()')
                % just catch the exception, no processing
            end
        end
        
        %% update checkpoints
        function updateCheckPoints(this)
            try
                checkpoints=[this.pathname 'checkpoints\' this.ObjectClasses{this.currentClassIndex} '.txt'];
                if(exist(checkpoints,'file'))
                    fileID = fopen(checkpoints,'r');
                    tline = fgets(fileID);
                    fclose(fileID);
                    if(str2num(tline)<this.fileIndex)
                        fileID = fopen(checkpoints,'w+');
                        fprintf(fileID,'%d \n',this.fileIndex);
                        fclose(fileID);
                    end
                end
                this.fileIndex=this.fileIndex+1;
                this.filename=this.files{this.fileIndex};
            catch
                disp('error on updateCheckPoints()')
            end
        end
        
        %% load the next image
        function nextImage(this,h,e)
            try
                maskAutoSave(this,h,e,0);% save the current mask before loading the next image
                if(this.fileIndex<length(this.files))
                    this.updateCheckPoints;
                    this.rawImage=imread([this.pathname this.filename]);
                    set(findobj('Tag','filename'),'String',this.filename);
                    str=[num2str(this.fileIndex) ' / ' num2str(length(this.files)) '  images'];
                    set(findobj('Tag','fileIndex'),'String',str);
                    this.ROIimage=this.rawImage;
                    this.ROI_x_offset=0;
                    this.ROI_y_offset=0;
                    this.superPixelsNumber=0;
                    this.newROI;
                    this.autoLoadMask;
                    this.updateROI;
                else
                    % just catch the exception, no processing
                end
            catch
                disp('error on nextImage()')
                % just catch the exception, no processing
            end
        end
        
        %% change the color of the currect object class
        function colorBar(this,~,~)
            try
                newColor=uisetcolor([0.0 1.0 0.0]);
                this.objectColors(this.currentClassIndex,:)=newColor;
                this.updateROI();
            catch
                disp('error on colorBar()')
                % just catch the exception, no processing
            end
        end
        
        %% Generate a new object class
        function newClass(this,~,~)
            try
                this.draw_type=0;
                this.draw_num=0;
                newName=inputdlg('Object Class Name:','New Object Class', [1 50]);
                if(size(newName,1)>0)
                    num=size(this.ObjectClasses,2);
                    exist=0;
                    for i=1:num
                        if strcmp(this.ObjectClasses{i},newName{1})
                            exist=1;
                            warndlg('Class already exists!!','Warnings!!');
                            break;
                        end
                    end
                    if exist==0
                        dim=size(this.rawImage);
                        this.rawMask(:,:,end+1)=zeros(dim(1:2));
                        dim=size(this.ROIimage);
                        this.ROImask(:,:,end+1)=zeros(dim(1:2));
                        this.ObjectClasses{end+1}=newName{1};
                        this.currentClassIndex=num+1;
                        if(size(this.ObjectClasses,2)>size(this.objectColors,1))
                            this.objectColors(end+1,:)=rand(1,3);
                        end
                    end
                    set(findobj('Tag','classList'),'String',this.ObjectClasses);
                else
                end
            catch
                disp('error on newClass()')
            end
        end
        
        %% select the object class to label
        function selectObjectClass(this,~,~)
            try
                this.draw_type=0;
                this.draw_num=0;
                indx=get(findobj('Tag','classList'),'Value');
                if(iscell(indx))
                    this.currentClassIndex=indx{1};
                else
                    this.currentClassIndex=indx;
                end
                this.updateROI;
            catch
                disp('error on selectObjectClass()')
                % just catch the exception, no processing
            end
        end
        
        %% change the width of paint and eraser
        function penWidth(this,~,~)
            try
                temp = get(findobj('Tag','width'),'Value');
                if(iscell(temp))
                    val = temp{1};
                else
                    val = temp;
                end
                this.penSize = val;
            catch
                disp('error on penWidth()')
            end
        end
        
        function changeTransparency(this,~,~)
            try
                temp=get(findobj('Tag','transparency'),'Value');
                if(iscell(temp))
                    val = temp{1};
                else
                    val = temp;
                end
                this.transparency = val/100.0;
                this.updateROI;
            catch
                disp('error on changeTransparency()')
            end
        end
        % UI FUNCTIONS ----------------------------------------------------
        function createWindow(this, ~, ~)
            try
                this.guifig=figure('MenuBar','none','Resize','on','Toolbar','none','Name','Mask Editor', ...
                    'NumberTitle','off','Color','white', 'units','normalized','position',this.winPos,...
                    'CloseRequestFcn',@this.closefig, 'visible','off');
                
                this.buttons = [];
                offset=0.25;
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style','edit',...
                    'units','normalized','FontSize',8,'HorizontalAlignment','center',...
                    'ForegroundColor','b',...
                    'Position',[0.05 0.985 0.9 0.015],'Tag','filename');
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style','text',...
                    'String', '0 / 0 images:','FontSize',10,'HorizontalAlignment','center',...
                    'BackgroundColor','w','ForegroundColor','b',...
                    'units','normalized','Position',[0.01 0.93 0.1 0.05],'Tag','fileIndex');
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style', 'text',...
                    'String', 'Transparency:','FontSize',10,'HorizontalAlignment','left',...
                    'BackgroundColor','w','ForegroundColor','k',...
                    'units','normalized','Position', [0.01 0.925 0.1 0.015]);
                
                this.buttons(end+1)= uicontrol('Style', 'slider',...
                    'Min',1,'Max',100,'Value',50,...
                    'units','normalized','Position', [0.01 0.9 0.1 0.015],...
                    'Callback', @(h,e)this.changeTransparency(h,e),'Tag','transparency');
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style', 'text',...
                    'String', 'Paint/Eraser Width:','FontSize',10,'HorizontalAlignment','left',...
                    'BackgroundColor','w','ForegroundColor','k',...
                    'units','normalized','Position', [0.01 0.875 0.1 0.015]);
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style', 'popup',...
                    'String', {1,2,3,4,5,6,7,8,9,10},'value', 3,...
                    'FontSize',10,'ForegroundColor','b',...
                    'units','normalized','Position', [0.01 0.85 0.1 0.015],...
                    'Callback', @(h,e)this.penWidth(h,e),'Tag','width');
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'String','Super Pixels',...
                    'units','normalized','FontSize',10,'HorizontalAlignment','center',...
                    'Position',[0.025 0.76 0.05 0.05], ...
                    'Callback',@(h,e)this.superPixel(h,e),'Tag','superPixels');
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style', 'text',...
                    'String', '# super pixels:','FontSize',10,'HorizontalAlignment','left',...
                    'BackgroundColor','w','ForegroundColor','k',...
                    'units','normalized','Position', [0.01 0.73 0.1 0.015]);
                
                this.buttons(end+1)= uicontrol('Style', 'slider',...
                    'Min',1,'Max',5000,'Value',100,...
                    'units','normalized','Position', [0.01 0.70 0.1 0.018],...
                    'Callback',@(h,e)this.superPixel(h,e),'Tag','superPixelNumber');
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style', 'text',...
                    'String', 'compactness:','FontSize',10,'HorizontalAlignment','left',...
                    'BackgroundColor','w','ForegroundColor','k',...
                    'units','normalized','Position', [0.01 0.68 0.1 0.015]);
                
                this.buttons(end+1)= uicontrol('Style', 'slider',...
                    'Min',1,'Max',10,'Value',5,...
                    'units','normalized','Position', [0.01 0.65 0.1 0.018],...
                    'Callback',@(h,e)this.superPixel(h,e),'Tag','compactness');
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style', 'text',...
                    'String', 'Iter number:','FontSize',10,'HorizontalAlignment','left',...
                    'BackgroundColor','w','ForegroundColor','k',...
                    'units','normalized','Position', [0.01 0.63 0.1 0.015]);
                
                this.buttons(end+1)= uicontrol('Style', 'slider',...
                    'Min',1,'Max',500,'Value',2,...
                    'units','normalized','Position', [0.01 0.60 0.1 0.018],...
                    'Callback',@(h,e)this.superPixel(h,e),'Tag','iterNumber');
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'String','New Class',...
                    'units','normalized','FontSize',15,...
                    'Position',[0.01 0.70-offset 0.1 0.1], ...
                    'Callback',@(h,e)this.newClass(h,e),'Tag','newClass');
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style', 'text',...
                    'String', 'Defect Class List:          ','FontSize',15,...
                    'BackgroundColor','w','ForegroundColor','k',...
                    'units','normalized','Position', [0.01 0.60-offset 0.1 0.025]);
                
                this.buttons(end+1) = uicontrol('Parent',this.guifig,'Style', 'listbox',...
                    'String', this.ObjectClasses,'FontSize',15,'ForegroundColor','b',...
                    'units','normalized','Position', [0.01 0.4-offset 0.1 0.2],...
                    'Callback', @(h,e)this.selectObjectClass(h,e),...
                    'Tag','classList');
                
                this.imax = axes('parent',this.guifig,'units','normalized','position',[0.15 0.05 0.83 0.93]);
                %             linkaxes(this.imax);
                
                % create toolbar
                this.createToolbar(this.guifig);
                
                % add listeners
                set(this.guifig,'WindowButtonDownFcn',@(h,e)this.winpressed(h,e,'down'));
                set(this.guifig,'WindowButtonMotionFcn',@(h,e)this.mousemove(h,e)) ;
                set(this.guifig,'WindowButtonUpFcn',@(h,e)this.winpressed(h,e,'up')) ;
                set(this.guifig,'WindowKeyPressFcn',@(h,e)this.keypressed(h,e));
            catch
                disp('error on createWindow()')
            end
        end
        
        function resizeWindow(this)
            try
                
                set(this.guifig,'units','normalized','position',this.winPos);
                %             movegui(this.guifig,'center');
                set(this.guifig,'visible','on');
            catch
                disp('error on resizeWindow()')
            end
        end
        
        function tb=createToolbar(this, fig)
            try
                tb = uitoolbar('parent',fig);
                
                this.hpt=[];
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('file_new.png'),...
                    'TooltipString','Open New Image',...
                    'ClickedCallback',...
                    @this.openImage,...
                    'Separator','on');
                %             this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('loadMask.jpg'),...
                %                 'TooltipString','load masks',...
                %                 'ClickedCallback',...
                %                 @this.openMask,...
                %                 'Separator','on');
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('file_open.png'),...
                    'TooltipString','Open Image Directory',...
                    'ClickedCallback',...
                    @this.openDir,...
                    'Separator','on');
                %             this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('file_save.png'),...
                %                 'TooltipString','Save Mask',...
                %                 'ClickedCallback',...
                %                 @this.maualSaveMask,...
                %                 'Separator','on');
                %---
                this.hpt(end+1) = uitoggletool(tb,'CData',localLoadIconCData('tool_zoom_in.png'),...
                    'TooltipString','Zoom In',...
                    'ClickedCallback',...
                    'putdowntext(''zoomin'',gcbo)',...
                    'Separator','on','Tag','tool_zoom_in');
                this.hpt(end+1) = uitoggletool(tb,'CData',localLoadIconCData('tool_zoom_out.png'),...
                    'TooltipString','Zoom Out',...
                    'ClickedCallback',...
                    'putdowntext(''zoomout'',gcbo)',...
                    'Separator','on','Tag','tool_zoom_out');
                
                this.hpt(end+1) = uitoggletool(tb,'CData',localLoadIconCData('tool_hand_orig.png'),...
                    'TooltipString','Pan',...
                    'ClickedCallback',...
                    'putdowntext(''pan'',gcbo)',...
                    'Separator','on','Tag','tool_hand');
                %---
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('ROI.jpg'),...
                    'TooltipString','ROI',...
                    'ClickedCallback',...
                    @this.ROIclick,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('UndoROI.jpg'),...
                    'TooltipString','Undo ROI',...
                    'ClickedCallback',...
                    @this.UndoROI,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('paint.jpg'),...
                    'TooltipString','Paint',...
                    'ClickedCallback',...
                    @this.paintclick,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('sketch.jpg'),...
                    'TooltipString','Sketch',...
                    'ClickedCallback',...
                    @this.freeclick,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('magic.jpg'),...
                    'TooltipString','Magic',...
                    'ClickedCallback',...
                    @this.magicClick,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('eraser.jpg'),...
                    'TooltipString','Eraser',...
                    'ClickedCallback',...
                    @this.eraserclick,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('delete.jpg'),...
                    'TooltipString','Delete',...
                    'ClickedCallback',...
                    @this.deleteclick,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('ellipse.jpg'),...
                    'TooltipString','Ellipse',...
                    'ClickedCallback',...
                    @this.elliclick,...
                    'Separator','on');
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('rect.jpg'),...
                    'TooltipString','Rectangle',...
                    'ClickedCallback',...
                    @this.rectclick,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('polygon.jpg'),...
                    'TooltipString','Polygon',...
                    'ClickedCallback',...
                    @this.polyclick,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('file_save.png'),...
                    'TooltipString','Apply Drawing and Save Mask',...
                    'ClickedCallback',...
                    @this.applyclick,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('previous.jpg'),...
                    'TooltipString','Previous Image',...
                    'ClickedCallback',...
                    @this.prevImage,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('next.jpg'),...
                    'TooltipString','Next Image',...
                    'ClickedCallback',...
                    @this.nextImage,...
                    'Separator','on');
                
                this.hpt(end+1) = uipushtool(tb,'CData',localLoadIconCData('tool_colorbar.png'),...
                    'TooltipString','Color bar',...
                    'ClickedCallback',...
                    @this.colorBar,...
                    'Separator','on');
            catch
                disp('error on createToolbar()')
            end
        end
    end  % end private methods
end


% this is copied from matlabs uitoolfactory.m, to load the icons for the toolbar
function cdata = localLoadIconCData(filename)
try
    % Loads CData from the icon files (PNG, GIF or MAT) in toolbox/matlab/icons.
    % filename = info.icon;
    
    % Load cdata from *.gif file
    persistent ICONROOT
    if isempty(ICONROOT)
        %         ICONROOT = fullfile(matlabroot,'toolbox','matlab','icons',filesep);
        ICONROOT = fullfile('icons',filesep);
    end
    
    if length(filename)>3 && strncmp(filename(end-3:end),'.gif',4)
        [cdata,map] = imread([ICONROOT,filename]);
        % Set all white (1,1,1) colors to be transparent (nan)
        ind = map(:,1)+map(:,2)+map(:,3)==3;
        map(ind) = NaN;
        cdata = ind2rgb(cdata,map);
        
        % Load cdata from *.png file
    elseif length(filename)>3 && strncmp(filename(end-3:end),'.png',4)
        %             [cdata map alpha] = imread(['./icons/' filename]);
        [cdata , ~, alpha] = imread(['icons','\',filename]);
        % Converting 16-bit integer colors to MATLAB colorspec
        cdata = double(cdata) / 65535.0;
        % Set all transparent pixels to be transparent (nan)
        cdata(alpha==0) = NaN;
    elseif strncmp(filename(end-3:end),'.jpg',4)
        %             [cdata map alpha] = imread(['./icons/' filename]);
        [cdata , ~, ~] = imread(['icons','\',filename]);
        cdata = imresize(cdata,[25 25]);
        % Converting 18-bit integer colors to MATLAB colorspec
        cdata = double(cdata) / 255.0;
        cdata(cdata>0.98) = NaN;
        % Load cdata from *.mat file
    else
        temp = load([ICONROOT,filename],'cdata');
        cdata = temp.cdata;
    end
catch
    disp('error on localLoadIconCData()')
end
end

