//
//  FirstViewController.m
//  zjtSinaWeiboClient
//
//  Created by jtone z on 11-11-25.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import "FirstViewController.h"
#import "ZJTHelpler.h"
#import "ZJTStatusBarAlertWindow.h"
#import "CoreDataManager.h"

@interface FirstViewController() 
-(void)timerOnActive;
-(void)getDataFromCD;
@end

@implementation FirstViewController
@synthesize userID;
@synthesize timer;

-(void)dealloc
{
    self.userID = nil;
    
    [timer invalidate];
    self.timer = nil;
    
    [super dealloc];
}

- (void)twitter
{
    TwitterVC *tv = [[TwitterVC alloc]initWithNibName:@"TwitterVC" bundle:nil];
    [self.navigationController pushViewController:tv animated:YES];
    [tv release];
}

-(void)getDataFromCD
{
    if (!statuesArr || statuesArr.count == 0) {
        statuesArr = [[NSMutableArray alloc] initWithCapacity:70];
        NSArray *arr = [[CoreDataManager getInstance] readStatusesFromCD];
        if (arr && arr.count != 0) {
            for (int i = 0; i < arr.count; i++) 
            {
                StatusCDItem *s = [arr objectAtIndex:i];
                Status *sts = [[Status alloc]init];
                sts = [sts updataStatusFromStatusCDItem:s];
                
                [statuesArr insertObject:sts atIndex:s.index.intValue];
            }
        }
    }
    [table reloadData];
    [self getImages];
}

							
#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *retwitterBtn = [[UIBarButtonItem alloc]initWithTitle:@"发微博" style:UIBarButtonItemStylePlain target:self action:@selector(twitter)];
    self.navigationItem.rightBarButtonItem = retwitterBtn;
    [retwitterBtn release];
        
    //如果未授权，则调入授权页面。
    NSString *authToken = [[NSUserDefaults standardUserDefaults] objectForKey:USER_STORE_ACCESS_TOKEN];
    NSLog([manager isNeedToRefreshTheToken] == YES ? @"need to login":@"will login");
    if (authToken == nil || [manager isNeedToRefreshTheToken]) 
    {
        shouldLoad = YES;
        OAuthWebView *webV = [[OAuthWebView alloc]initWithNibName:@"OAuthWebView" bundle:nil];
        webV.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:webV animated:NO];
        [webV release];
    }
    else
    {
        [self getDataFromCD];
        
        if (!statuesArr || statuesArr.count == 0) {
            [manager getHomeLine:-1 maxID:-1 count:-1 page:-1 baseApp:-1 feature:-1];
            [[SHKActivityIndicator currentIndicator] displayActivity:@"正在载入..." inView:self.view];
        }
        
        [manager getUserID];
    }
    [defaultNotifCenter addObserver:self selector:@selector(didGetUserID:)      name:MMSinaGotUserID            object:nil];
    [defaultNotifCenter addObserver:self selector:@selector(didGetHomeLine:)    name:MMSinaGotHomeLine          object:nil];
    [defaultNotifCenter addObserver:self selector:@selector(didGetUserInfo:)    name:MMSinaGotUserInfo          object:nil];
    [defaultNotifCenter addObserver:self selector:@selector(relogin)            name:NeedToReLogin              object:nil];
    [defaultNotifCenter addObserver:self selector:@selector(didGetUnreadCount:) name:MMSinaGotUnreadCount       object:nil];
    [defaultNotifCenter addObserver:self selector:@selector(appWillResign:)            name:UIApplicationWillResignActiveNotification             object:nil];
}

-(void)viewDidUnload
{
    [defaultNotifCenter removeObserver:self name:MMSinaGotUserID            object:nil];
    [defaultNotifCenter removeObserver:self name:MMSinaGotHomeLine          object:nil];
    [defaultNotifCenter removeObserver:self name:MMSinaGotUserInfo          object:nil];
    [defaultNotifCenter removeObserver:self name:NeedToReLogin              object:nil];
    [defaultNotifCenter removeObserver:self name:MMSinaGotUnreadCount       object:nil];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
    if (shouldLoad) 
    {
        shouldLoad = NO;
        [manager getUserID];
        [manager getHomeLine:-1 maxID:-1 count:-1 page:-1 baseApp:-1 feature:-1];
        [[SHKActivityIndicator currentIndicator] displayActivity:@"正在载入..." inView:self.view];
//        [[ZJTStatusBarAlertWindow getInstance] showWithString:@"正在载入，请稍后..."];
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

#pragma mark - Methods

-(void)appWillResign:(id)sender
{
    for (int i = 0; i < statuesArr.count; i++) {
        NSLog(@"i = %d",i);
        [[CoreDataManager getInstance] insertStatusesToCD:[statuesArr objectAtIndex:i] index:i isHomeLine:YES];
    }
}

-(void)timerOnActive
{
    [manager getUnreadCount:userID];
}

-(void)relogin
{
    shouldLoad = YES;
    OAuthWebView *webV = [[OAuthWebView alloc]initWithNibName:@"OAuthWebView" bundle:nil];
    webV.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:webV animated:NO];
    [webV release];
}

-(void)didGetUserID:(NSNotification*)sender
{
    self.userID = sender.object;
    [[NSUserDefaults standardUserDefaults] setObject:userID forKey:USER_STORE_USER_ID];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [manager getUserInfoWithUserID:[userID longLongValue]];
}

-(void)didGetUserInfo:(NSNotification*)sender
{
    User *user = sender.object;
    [ZJTHelpler getInstance].user = user;
    [[NSUserDefaults standardUserDefaults] setObject:user.screenName forKey:USER_STORE_USER_NAME];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)didGetHomeLine:(NSNotification*)sender
{
    if ([sender.object count] == 1) {
        NSDictionary *dic = [sender.object objectAtIndex:0];
        NSString *error = [dic objectForKey:@"error"];
        if (error && ![error isEqual:[NSNull null]]) {
            if ([error isEqualToString:@"expired_token"]) 
            {
                [[SHKActivityIndicator currentIndicator] hide];
//                [[ZJTStatusBarAlertWindow getInstance] hide];
                shouldLoad = YES;
                OAuthWebView *webV = [[OAuthWebView alloc]initWithNibName:@"OAuthWebView" bundle:nil];
                webV.hidesBottomBarWhenPushed = YES;
                [self.navigationController pushViewController:webV animated:NO];
                [webV release];
            }
            return;
        }
    }
    
    [self stopLoading];
    [self doneLoadingTableViewData];
    
    [statuesArr removeAllObjects];
    self.statuesArr = sender.object;
    [table reloadData];
    //[self.tableView reloadData];
    
    [[SHKActivityIndicator currentIndicator] hide];
    [[ZJTStatusBarAlertWindow getInstance] hide];
    
    [headDictionary  removeAllObjects];
    [imageDictionary removeAllObjects];
    
    [self getImages];
    
    if (timer == nil) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(timerOnActive) userInfo:nil repeats:YES];
    }
}

-(void)didGetUnreadCount:(NSNotification*)sender
{
    NSDictionary *dic = sender.object;
    NSNumber *num = [dic objectForKey:@"status"];
    
    NSLog(@"num = %@",num);
    if ([num intValue] == 0) {
        return;
    }
    
    [[ZJTStatusBarAlertWindow getInstance] showWithString:[NSString stringWithFormat:@"有%@条新微博",num]];
    [[ZJTStatusBarAlertWindow getInstance] performSelector:@selector(hide) withObject:nil afterDelay:10];
}

@end