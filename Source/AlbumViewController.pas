﻿namespace Browse500;

interface

uses
  PXAPI,
  UIKit;

type
  AlbumViewController = public class(UIViewController, IUITableViewDataSource, IUITableViewDelegate, IUICollectionViewDataSource, IUICollectionViewDelegate)
  private
    fUserID: Int32;
    fFeature: PXAPIHelperPhotoFeature;
    fCurrentPage: Int32;
    fPhotosSmall: NSCache;// := new NSMutableDictionary;  << THIS throws an exception
    fCategories: NSDictionary;
    fUserInfo: NSDictionary;
    
    fPhotosPerPage: UInt32; 
    fPhotoInfo: NSArray;
    fReloading: Boolean;
    fDone: Boolean;


    method loadNextPage; 
    method photosChanged(aNotification: NSNotification);

    method showUserInfo(aSender: id);

    property tableView: UITableView;
    fCollectionView: UICollectionView;
    fCollectionViewLayout: UICollectionViewFlowLayout;
    //property tableView2 := UITableView; //log: weird error
    method setCollectionViewInsetForOrientation(aInterfaceOrientation: UIInterfaceOrientation);

    method SetImageOnCell(aPhotoInfo: NSDictionary; aCell: id);
    method DrillIntoPhotoAtIndexPath(aIndexPath: NSIndexPath);

  protected

    property albumType: AlbumType; 
    property ShouldCacheThumbnails: Boolean;

    method doLoadNextPage(aPage: Int32; aBlock: NewPhotosBlock); virtual;
    method reloadPhotos(aNotification: NSNotification);

    {$REGION Table view data source & delegate - used on iPhone}
    method tableView(aTableView: UITableView) numberOfRowsInSection(section: Integer): Integer;
    method tableView(aTableView: UITableView) cellForRowAtIndexPath(indexPath: NSIndexPath): UITableViewCell;
    method tableView(aTableView: UITableView) willDisplayCell(cell: UITableViewCell) forRowAtIndexPath(indexPath: NSIndexPath);
    method tableView(aTableView: UITableView) didSelectRowAtIndexPath(indexPath: NSIndexPath);
    {$ENDREGION}

    {$REGION Table view data source & delegate - used on iPad}
    method collectionView(collectionView: UICollectionView) numberOfItemsInSection(section: NSInteger): NSInteger;
    method collectionView(collectionView: UICollectionView) cellForItemAtIndexPath(indexPath: NSIndexPath): UICollectionViewCell;
    method collectionView(collectionView: UICollectionView) didSelectItemAtIndexPath(indexPath: NSIndexPath): RemObjects.Oxygene.System.Boolean;
    {$ENDREGION}

  public
    method init: id; override;
    method initWithUserID(aUserID: Int32): id;
    method initWithUserInfo(aUserInfo: NSDictionary): id;
    method initWithFeature(aFeature: PXAPIHelperPhotoFeature): id;
    method dealloc; override;

    method viewDidLoad; override;
    method viewWillAppear(aAnimated: Boolean); override;
    method didReceiveMemoryWarning; override;
    method willRotateToInterfaceOrientation(aToInterfaceOrientation: UIInterfaceOrientation) duration(aDuration: NSTimeInterval); override;

    const FEATURE_TITLES: array of String = ['Popular', 'Upcoming', 'Editors', 'Fresh Today', 'Fresh Yesterday', 'Fresh This Week'];
    const CELL_IDENTIFIER = 'ALBUM_VIEW_CELL';
  end;

  NewPhotosBlock = public block(aNewPhotos: NSArray);

implementation

method AlbumViewController.init: id;
begin
  self := inherited init;//WithStyle(UITableViewStyle.UITableViewStylePlain);
  if assigned(self) then begin

    // Custom initialization

  end;
  result := self;
end;

method AlbumViewController.initWithUserID(aUserID: Int32): id;
begin
  self := init;
  if assigned(self) then begin

    fFeature := PXAPIHelperPhotoFeature(-1);
    fUserID := aUserID;
    albumType := albumType.User;

  end;
  result := self;
end;

method AlbumViewController.initWithUserInfo(aUserInfo: NSDictionary): id;
begin
  self := init;
  if assigned(self) then begin

    fFeature := PXAPIHelperPhotoFeature(-1);
    fUserID := aUserInfo['id'].integerValue;
    fUserInfo := aUserInfo;
    albumType := albumType.User;

  end;
  result := self;
end;

method AlbumViewController.initWithFeature(aFeature: PXAPIHelperPhotoFeature): id;
begin
  self := init;
  if assigned(self) then begin

    fFeature := aFeature;
    fUserID := -1;
    albumType := albumType.Featured;

  end;
  result := self;
end;

method AlbumViewController.dealloc;
begin
  NSLog('AlbumViewController.dealloc');
end;

method AlbumViewController.viewDidLoad;
begin
  inherited viewDidLoad;

  fCollectionViewLayout := new UICollectionViewFlowLayout;
  fCollectionView := new UICollectionView withFrame(view.bounds) collectionViewLayout(fCollectionViewLayout);
  fCollectionView.delegate := self;
  fCollectionView.dataSource := self;
  fCollectionView.backgroundColor := UIColor.colorWithRed(0.1) green(0.1) blue(0.1) alpha(1.0);

  if UIDevice.currentDevice.userInterfaceIdiom = UIUserInterfaceIdiom.UIUserInterfaceIdiomPhone then begin
    {tableView := new UITableView;
    tableView.delegate := self;
    tableView.dataSource := self;
    tableView.reloadData();
    view := tableView;

    tableView.separatorColor := UIColor.colorWithRed(0.1) green(0.2) blue(0.2) alpha(1.0);
    tableView.backgroundColor := UIColor.colorWithRed(0.1) green(0.1) blue(0.1) alpha(1.0);}

    fCollectionViewLayout.itemSize := CGSizeMake(100, 100);
    fCollectionViewLayout.minimumInteritemSpacing := 5;
    fCollectionViewLayout.minimumLineSpacing := 5;
    setCollectionViewInsetForOrientation(UIApplication.sharedApplication.statusBarOrientation);

    fPhotosPerPage := 30;
  end
  else begin
    fCollectionViewLayout.itemSize := CGSizeMake(179, 179);
    fCollectionViewLayout.minimumInteritemSpacing := 10;
    fCollectionViewLayout.minimumLineSpacing := 10;
    setCollectionViewInsetForOrientation(UIApplication.sharedApplication.statusBarOrientation);

    fPhotosPerPage := 100;
  end;

  fCollectionView.registerClass(UICollectionViewCell.class) forCellWithReuseIdentifier(CELL_IDENTIFIER);
  fCollectionView.reloadData();
  view := fCollectionView;



  NSNotificationCenter.defaultCenter.addObserver(self) 
                                    &selector(selector(photosChanged:)) 
                                    name(Preferences.NOTIFICATION_SHOW_NSFW_CHANGED)
                                    object(Preferences.sharedInstance);

  {PXRequest.requestForUserWithUserName('dwarfland') completion(method (aResult: NSDictionary; aError: NSError) 
                                                               begin
                                                                 NSLog('done! %@', aResult);
                                                               end);}
  
  if fFeature <> -1 then begin
    title := FEATURE_TITLES[fFeature];
  end
  else if not assigned(fUserInfo) then begin
    title := '∞';
    PXRequest.requestForUserWithID(fUserID) 
              completion(method (aResult: NSDictionary; aError: NSError) 
                         begin
                           NSLog('user info %@', aResult);
                           if assigned(aResult) then begin
                             fUserInfo := aResult['user'];
                             title := fUserInfo['username'];
                                                         
                             RootViewController.instance.addUser(fUserInfo);
                             navigationController:navigationBar:topItem:rightBarButtonItem := new UIBarButtonItem withBarButtonSystemItem(UIBarButtonSystemItem.UIBarButtonSystemItemCamera) target(self) action(selector(showUserInfo:));
                           end;
                         end);
  end
  else begin
    title := fUserInfo['username'];
  end;
  
  fCategories := NSDictionary.dictionaryWithContentsOfFile(NSBundle.mainBundle.pathForResource('Categories') ofType('plist'));
  fPhotosSmall := new NSCache;
  //fPhotosSmall.countLimit := fPhotosPerPage*3;
  fPhotosSmall.setCountLimit(fPhotosPerPage*3);
  
  loadNextPage();
end;

method AlbumViewController.setCollectionViewInsetForOrientation(aInterfaceOrientation: UIInterfaceOrientation);
begin
  if  not assigned(fCollectionViewLayout) then exit;

  if UIDevice.currentDevice.userInterfaceIdiom = UIUserInterfaceIdiom.UIUserInterfaceIdiomPad then begin
    case aInterfaceOrientation of
      UIInterfaceOrientation.UIInterfaceOrientationLandscapeLeft,
      UIInterfaceOrientation.UIInterfaceOrientationLandscapeRight:     fCollectionViewLayout.sectionInset := UIEdgeInsetsMake(11, 45, 11, 44);
      UIInterfaceOrientation.UIInterfaceOrientationPortrait,
      UIInterfaceOrientation.UIInterfaceOrientationPortraitUpsideDown: fCollectionViewLayout.sectionInset := UIEdgeInsetsMake(11, 11, 11, 11);
    end;
  end 
  else begin
    fCollectionViewLayout.sectionInset := UIEdgeInsetsMake(5, 5, 5, 5);
  end;
end;

method AlbumViewController.viewWillAppear(aAnimated: Boolean);
begin
  setCollectionViewInsetForOrientation(UIApplication.sharedApplication.statusBarOrientation);
end;

method AlbumViewController.willRotateToInterfaceOrientation(aToInterfaceOrientation: UIInterfaceOrientation) duration(aDuration: NSTimeInterval);
begin
  setCollectionViewInsetForOrientation(aToInterfaceOrientation);
end;

method AlbumViewController.didReceiveMemoryWarning;
begin
  inherited didReceiveMemoryWarning;
  NSLog('AlbumViewController.didReceiveMemoryWarning');
  fPhotosSmall.removeAllObjects();
  // Dispose of any resources that can be recreated.
end;

method AlbumViewController.reloadPhotos(aNotification: NSNotification);
begin
  fCurrentPage := 0;
  fPhotoInfo := nil;
  fDone := false;
  fReloading := false;
  loadNextPage();
end;

method AlbumViewController.photosChanged(aNotification: NSNotification);
begin
  if assigned(tableView) then tableView.reloadData;
  if assigned(fCollectionView) then fCollectionView.reloadData;
end;

method AlbumViewController.showUserInfo(aSender: id);
begin

end;

method AlbumViewController.doLoadNextPage(aPage: Int32; aBlock: NewPhotosBlock);
begin

  var lBlock := method (aResult: NSDictionary; aError: NSError) 
                         begin
                           AppDelegate.decreaseNetworkActivityIndicator();
                           if assigned(aResult) then begin
                             var lNewPhotos := aResult['photos'];
                             aBlock(lNewPhotos);
                           end
                           else if assigned(aError) then begin
                             var a := new UIAlertView withTitle('Error') 
                                                          message(aError.description) 
                                                          &delegate(nil) 
                                                          cancelButtonTitle('Ok') 
                                                          otherButtonTitles(nil);
                             a.show();
                             fReloading := false;
                           end;
                         end;     
                         
  if fFeature <> -1 then begin 
    AppDelegate.increaseNetworkActivityIndicator();
    PXRequest.requestForPhotoFeature(fFeature) 
              resultsPerPage(fPhotosPerPage) 
              page(fCurrentPage+1)
              completion(lBlock);
  end
  else begin
    AppDelegate.increaseNetworkActivityIndicator();
    PXRequest.requestForPhotosOfUserID(fUserID) 
              userFeature(PXAPIHelperUserPhotoFeature.PXAPIHelperUserPhotoFeaturePhotos)
              resultsPerPage(fPhotosPerPage)
              page(fCurrentPage+1) 
              completion(lBlock);
  end;

end;

method AlbumViewController.loadNextPage();
begin
  NSLog('AlbumViewController.loadNextPage 1 %d, %d', fReloading, fDone);
  if fReloading or fDone then exit;
  NSLog('AlbumViewController.loadNextPage 2');

  fReloading := true;
  {dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), method} begin

      NSLog('loading page %d', fCurrentPage+1);
      doLoadNextPage(fCurrentPage+1, method (aNewPhotos: NSArray) begin

          NSLog('AlbumViewController.loadNextPage 3');

          dispatch_async(dispatch_get_main_queue(), method begin
              NSLog('AlbumViewController.loadNextPage 4');
              if assigned(aNewPhotos) and (aNewPhotos.count > 0) then begin

                if assigned(fPhotoInfo) then
                  fPhotoInfo := fPhotoInfo.arrayByAddingObjectsFromArray(aNewPhotos)
                else
                  fPhotoInfo := aNewPhotos;
                inc(fCurrentPage);
                photosChanged(nil);
              end
              else begin
                fDone := true;                          
                photosChanged(nil);
              end;
              fReloading := false;
              NSLog('AlbumViewController.loadNextPage 5');

            end);

        end);

  end;
end;

method AlbumViewController.DrillIntoPhotoAtIndexPath(aIndexPath: NSIndexPath);
begin
  var lPhoto := fPhotoInfo[aIndexPath.row];

  //if aPhotoInfo is not NSDictionary then begin // Error	3	(E0) Internal error: LPUSHB->D22	Z:\Code\Nougat Tests\Browse500\Source\AlbumViewController.pas	331	6	Browse500
  if not (lPhoto is NSDictionary) then exit;

  var lViewController := new PhotoViewController withPhotoInfo(lPhoto) viaAlbumType(albumType);
  navigationController.pushViewController(lViewController) animated(true);
end;

method AlbumViewController.SetImageOnCell(aPhotoInfo: NSDictionary; aCell: id);
begin
  //if aPhotoInfo is not NSDictionary then begin // Error	3	(E0) Internal error: LPUSHB->D22	Z:\Code\Nougat Tests\Browse500\Source\AlbumViewController.pas	331	6	Browse500
  if not (aPhotoInfo is NSDictionary) then begin 
    if aCell is UITableViewCell then aCell.image := UIImage.imageNamed('234-cloud'); // our CollectionViewCell handles this by default
    exit;
  end;

  var lPhotoID{: weak id} := aPhotoInfo['id'];
  var lCategory := aPhotoInfo['category'].intValue;

  if (not Preferences.sharedInstance.ShowNSFW) and (lCategory = AppDelegate.CATEGORY_NSFW) then begin
    //not (aCell as INSObject).respondsToSelector(selector(blocked)) << why cast needed?
    if aCell is UITableViewCell then
      aCell.image := UIImage.imageNamed('298-circlex')
    else
      (aCell as AlbumCollectionViewCell).blocked := true; // NRE without the cast, here
    aCell.setNeedsLayout();
    exit;
  end;

  //60034: Nougat: crash if nested block tries to capture local var defined in outer block
  var lUIImage: UIImage; // log this!

  var lImage := fPhotosSmall.objectForKey(lPhotoID);
  if assigned(lImage) then begin
    aCell.image := lImage;
  end
  else begin
    
    if aCell is UITableViewCell then aCell.image := UIImage.imageNamed('234-cloud'); // our CollectionViewCell handles this by default

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), method begin

        var lCacheURL := Preferences.sharedInstance.CacheURL.URLByAppendingPathComponent(lPhotoID+'.jpg');
        var lFromCache := NSFileManager.defaultManager.fileExistsAtPath(lCacheURL.path);
        
        var lData: NSData;
        if lFromCache then begin
          lData := NSData.dataWithContentsOfURL(lCacheURL);
        end
        else begin
          AppDelegate.increaseNetworkActivityIndicator();
          lData := NSData.dataWithContentsOfURL(NSURL.URLWithString(aPhotoInfo['image_url'].objectAtIndex(0)));
          AppDelegate.decreaseNetworkActivityIndicator();
        end;

        if not assigned(lData) then exit;
        {var} lUIImage := UIImage.imageWithData(lData);
        if not assigned(lUIImage) then exit;


        fPhotosSmall.setObject(lUIImage) forKey(lPhotoID);

        dispatch_async(dispatch_get_main_queue(), method begin
            aCell.image := lUIImage;
            aCell.setNeedsLayout();
          end);

        if not lFromCache and ShouldCacheThumbnails  then 
          //crashes. log tomorrow
          {dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), metho} begin

              NSLog('caching tbhumbnail: %@', lCacheURL);
              lData.writeToURL(lCacheURL) atomically(true); 
            end;

    end);
  end; 
end;

{$REGION Table view data source & delegate - used on iPhone}
method AlbumViewController.tableView(aTableView: UITableView) numberOfRowsInSection(section: Integer): Integer;
begin
  result := if assigned(fPhotoInfo) then (fPhotoInfo.count + if not fDone then 1 else 0) else 0;
end;

method AlbumViewController.tableView(aTableView: UITableView) cellForRowAtIndexPath(indexPath: NSIndexPath): UITableViewCell;
begin
  var CellIdentifier := "Cell";

  result := tableView.dequeueReusableCellWithIdentifier(CellIdentifier);
  if not assigned(result) then begin
    result := new UITableViewCell withStyle(UITableViewCellStyle.UITableViewCellStyleSubtitle) reuseIdentifier(CellIdentifier);

    result.textLabel.font := UIFont.systemFontOfSize(18);
    result.textLabel.textColor := UIColor.lightGrayColor;
    result.detailTextLabel.textColor := UIColor.darkGrayColor;
    result.textAlignment := NSTextAlignment.NSTextAlignmentLeft;
  end;

  if (indexPath.row = fPhotoInfo.count) then begin
    result.image := nil;
    result.detailTextLabel.text := nil;
    result.textAlignment := NSTextAlignment.NSTextAlignmentCenter;
    if fReloading then begin
      result.textLabel.text := 'there''s more...';
    end
    else begin
      result.textLabel.text := 'loading more photos...';
      result.image := UIImage.imageNamed('234-cloud');
    end;

    
    loadNextPage();
    //self.tableView(tableView) didSelectRowAtIndexPath(indexPath); // force load of next batch.
    exit; 
  end;

  var lInfo := fPhotoInfo[indexPath.row];
  if lInfo is NSDictionary then begin
    result.textLabel.text := lInfo['name']:stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet);
    result.detailTextLabel.text := fCategories[lInfo['category'].stringValue]; // dictionary wants strings, not NSNumbers as key
  end
  else begin
    result.textLabel.text := '';
    result.detailTextLabel.text := 'syncing from iCloud...'
  end;
  SetImageOnCell(lInfo, result);

end;

method AlbumViewController.tableView(aTableView: UITableView) willDisplayCell(cell: UITableViewCell) forRowAtIndexPath(indexPath: NSIndexPath);
begin
  cell.backgroundColor := tableView.backgroundColor;
end;

method AlbumViewController.tableView(aTableView: UITableView) didSelectRowAtIndexPath(indexPath: NSIndexPath);
begin

  if (indexPath.row = fPhotoInfo.count) then begin 
    fReloading := true;
    //tableView.deleteRowsAtIndexPaths(NSArray.arrayWithObject(indexPath)) withRowAnimation(UITableViewRowAnimation.UITableViewRowAnimationBottom);
    loadNextPage();
    exit;
  end;

  DrillIntoPhotoAtIndexPath(indexPath);
  tableView.deselectRowAtIndexPath(indexPath) animated(true);
end;
{$ENDREGION}

{$REGION Table view data source & delegate - used on iPad}
method AlbumViewController.collectionView(collectionView: UICollectionView) numberOfItemsInSection(section: NSInteger): NSInteger;
begin
  //result := if assigned(fPhotoInfo) then fPhotoInfo.count);// + if not fDone then 1 else 0) else 0;
  result := if assigned(fPhotoInfo) then fPhotoInfo.count else 0;
end;

method AlbumViewController.collectionView(collectionView: UICollectionView) cellForItemAtIndexPath(indexPath: NSIndexPath): UICollectionViewCell;
begin
  // log/investigate: +[AlbumCollectionViewCell _setReuseIdentifier:]: unrecognized selector sent to class 0x3a3e0
  result := collectionView.dequeueReusableCellWithReuseIdentifier(CELL_IDENTIFIER) forIndexPath(indexPath);
  result.frame := CGRectMake(0.0, 0.0, fCollectionViewLayout.itemSize.width, fCollectionViewLayout.itemSize.height);

  //var lTempCell := result; //59851: Nougat: two block issues with var capturing (cant capture "result" yet)

  // until we can make Cell subclasses work properly
  var lView := new AlbumCollectionViewCell withFrame(result.frame);
  result.contentView.subviews.makeObjectsPerformSelector(selector(removeFromSuperview));
  result.contentView.addSubview(lView);

  if (UInt32(indexPath.row) > fPhotoInfo.count - fPhotosPerPage) then begin

    loadNextPage();
    //if indexPath.row = fPhotoInfo.count then exit; // no photo on the last item
  end;

  var lInfo := fPhotoInfo[indexPath.row];
  SetImageOnCell(lInfo, lView);
end;

method AlbumViewController.collectionView(collectionView: UICollectionView) didSelectItemAtIndexPath(indexPath: NSIndexPath): RemObjects.Oxygene.System.Boolean;
begin
  DrillIntoPhotoAtIndexPath(indexPath);
  collectionView.deselectItemAtIndexPath(indexPath) animated(true);
end;
{$ENDREGION}





end.
