﻿namespace Browse500;

interface

uses
  UIKit,
  PXAPI;

type
  AppDelegate = class(IUIApplicationDelegate)
  private
    class var fNetworkActivityIndicatorCounter: Int32;

    class fShowNSFW : Boolean;
    class method set_ShowNSFW(aValue: Boolean);

  public
    class constructor;

    property window: UIWindow;

    method application(application: UIApplication) didFinishLaunchingWithOptions(launchOptions: NSDictionary): Boolean;
    method applicationWillResignActive(application: UIApplication);
    method applicationDidEnterBackground(application: UIApplication);
    method applicationWillEnterForeground(application: UIApplication);
    method applicationDidBecomeActive(application: UIApplication);
    method applicationWillTerminate(application: UIApplication);

    const USERID_DWARFLAND = 145630;

    const SETTING_SHOW_NSFW = 'ShowNudeCategory';
    const CATEGORY_NSFW = 4;

    class property ShowNSFW: Boolean read fShowNSFW write set_ShowNSFW;

    class method increaseNetworkActivityIndicator;
    class method decreaseNetworkActivityIndicator;
  end;

implementation

class constructor AppDelegate;
begin
  fShowNSFW := NSUserDefaults.standardUserDefaults.boolForKey(SETTING_SHOW_NSFW);
end;

class method AppDelegate.set_ShowNSFW(aValue: Boolean);
begin
  fShowNSFW := aValue;
  NSUserDefaults.standardUserDefaults.setBool(aValue) forKey(SETTING_SHOW_NSFW);
  NSUserDefaults.standardUserDefaults.synchronize;
end;

method AppDelegate.application(application: UIApplication) didFinishLaunchingWithOptions(launchOptions: NSDictionary): Boolean;
begin
  self.window := new UIWindow withFrame(UIScreen.mainScreen.bounds);

  PXRequest.setConsumerKey('AUkCkCFi8IYuhNcWGbg4cAYoSTPVIuUGbGpEg4hC') consumerSecret('3sNoDmmLYZjdBvrjXTuxlH878UsIYuhybYAtIJij');

  var lNavigationController := new UINavigationController withRootViewController(new RootViewController);
  lNavigationController.navigationBar.tintColor := UIColor.colorWithRed(0.2) green(0.2) blue(0.2) alpha(1.0);
  lNavigationController.pushViewController(new AlbumViewController withUserID(USERID_DWARFLAND)) animated(false);

  window.rootViewController := lNavigationController;

  self.window.makeKeyAndVisible;
  
  result := true;
end;

method AppDelegate.applicationWillResignActive(application: UIApplication);
begin
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
end;

method AppDelegate.applicationDidEnterBackground(application: UIApplication);
begin
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
end;

method AppDelegate.applicationWillEnterForeground(application: UIApplication);
begin
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
end;

method AppDelegate.applicationDidBecomeActive(application: UIApplication);
begin
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
end;

method AppDelegate.applicationWillTerminate(application: UIApplication);
begin
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
end;


class method AppDelegate.increaseNetworkActivityIndicator;
begin
    inc(fNetworkActivityIndicatorCounter);
    if fNetworkActivityIndicatorCounter = 1 then
      UIApplication.sharedApplication.setNetworkActivityIndicatorVisible(true);
end;

class method AppDelegate.decreaseNetworkActivityIndicator;
begin
  dec(fNetworkActivityIndicatorCounter);
  if fNetworkActivityIndicatorCounter ≤ 0 then begin
    UIApplication.sharedApplication.setNetworkActivityIndicatorVisible(false);
    fNetworkActivityIndicatorCounter := 0;
  end;
end;

end.
