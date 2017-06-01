//
//  ViewController.m
//  SZDownloadDemo
//
//  Created by cnbs_01 on 17/6/1.
//  Copyright © 2017年 StenpZ. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"首页";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"下载" style:UIBarButtonItemStylePlain target:self action:@selector(showDownloadList)];
}

- (void)showDownloadList {
    UIViewController *vc = [[NSClassFromString(@"TableViewController") alloc] initWithStyle:UITableViewStyleGrouped];
    vc.navigationItem.title = @"下载中心";
    [self.navigationController pushViewController:vc animated:true];
}


@end
