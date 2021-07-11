//
//  MainTableViewController.m
//  MMSession
//
//  Created by youjianxia on 7/9/21.
//

#import "MainViewController.h"
#import "CameraViewController.h"
#import "EditViewController.h"

#define kRandom(r, g, b, a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)/255.0]
#define kRandomColor kRandom(arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256))

@interface MainViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSArray<NSString *> *data;
@property (nonatomic, weak) UITableView *tableView;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Main";
    self.navigationController.navigationBar.barTintColor = UIColor.purpleColor;
    self.data = @[@"视频采集", @"视频编辑"];
    
    CGFloat w = self.view.bounds.size.width;
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, w, w*16/9)];
    tableView.scrollEnabled = NO;
    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:tableView];
    tableView.dataSource = self;
    tableView.delegate = self;
    self.tableView = tableView;
}

#pragma mark - UITableViewDataSource & UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.data.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *indentifier = @"mmsession_cell_indentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:indentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:indentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = self.data[indexPath.row];
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    cell.backgroundColor = kRandomColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self _transAnimation];
    
    if ([self.data[indexPath.row] isEqualToString:@"视频采集"]) {
        [self.navigationController pushViewController:[[CameraViewController alloc] init] animated:NO];
    } else if ([self.data[indexPath.row] isEqualToString:@"视频编辑"])  {
        [self.navigationController pushViewController:[[EditViewController alloc] init] animated:NO];
    }
}

#pragma mark - Private
- (void)_transAnimation {
    CATransition *animation = [CATransition animation];
    [animation setDuration:0.5f];
    [animation setType:kCATransitionFade];
    [animation setSubtype:kCATransitionFromTop];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
    [self.navigationController.view.layer addAnimation:animation forKey:nil];
}

@end
