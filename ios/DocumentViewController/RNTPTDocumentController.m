#import "RNTPTDocumentController.h"

NS_ASSUME_NONNULL_BEGIN

@interface RNTPTDocumentController ()

@property (nonatomic) BOOL settingBottomToolbarsEnabled;

@property (nonatomic) BOOL local;
@property (nonatomic) BOOL needsDocumentLoaded;
@property (nonatomic) BOOL needsRemoteDocumentLoaded;
@property (nonatomic) BOOL documentLoaded;

@end

NS_ASSUME_NONNULL_END

@implementation RNTPTDocumentController

@dynamic delegate;

- (void)setThumbnailSliderHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (!hidden) {
        return;
    }
    [super setThumbnailSliderHidden:hidden animated:animated];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    if (self.needsDocumentLoaded) {
        self.needsDocumentLoaded = NO;
        self.needsRemoteDocumentLoaded = NO;
        self.documentLoaded = YES;
        
        if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerDocumentLoaded:)]) {
            [self.delegate rnt_documentViewControllerDocumentLoaded:self];
        }
    }
}

- (void)openDocumentWithURL:(NSURL *)url password:(NSString *)password
{
    if ([url isFileURL]) {
        self.local = YES;
    } else {
        self.local = NO;
    }
    self.documentLoaded = NO;
    self.needsDocumentLoaded = NO;
    self.needsRemoteDocumentLoaded = NO;
    
    [super openDocumentWithURL:url password:password];
}

- (void)openDocumentWithPDFDoc:(PTPDFDoc *)document
{
    self.local = YES;
    self.documentLoaded = NO;
    self.needsDocumentLoaded = NO;
    self.needsRemoteDocumentLoaded = NO;

    [super openDocumentWithPDFDoc:document];
}

- (BOOL)isTopToolbarEnabled
{
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerIsTopToolbarEnabled:)]) {
        return [self.delegate rnt_documentViewControllerIsTopToolbarEnabled:self];
    }
    return YES;
}

- (BOOL)areTopToolbarsEnabled
{
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerAreTopToolbarsEnabled:)]) {
        return [self.delegate rnt_documentViewControllerAreTopToolbarsEnabled:self];
    }
    return YES;
}

- (BOOL)isNavigationBarEnabled
{
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerIsNavigationBarEnabled:)]) {
        return [self.delegate rnt_documentViewControllerIsNavigationBarEnabled:self];
    }
    return YES;
}

- (void)setControlsHidden:(BOOL)controlsHidden animated:(BOOL)animated
{
    [super setControlsHidden:controlsHidden animated:animated];
    
    if ([self areTopToolbarsEnabled] &&
        ![self isNavigationBarEnabled] &&
        self.tabbedDocumentViewController) {
        [self.tabbedDocumentViewController setTabBarHidden:controlsHidden animated:animated];
    }
}

- (BOOL)shouldExportCachedDocumentAtURL:(nonnull NSURL *)cachedDocumentURL
{
    return NO;
}

#pragma mark - <PTToolManagerDelegate>

- (void)toolManagerToolChanged:(PTToolManager *)toolManager
{
    [PTColorDefaults setDefaultColor:[UIColor greenColor] forAnnotType:PTExtendedAnnotTypeCircle attribute:ATTRIBUTE_STROKE_COLOR colorPostProcessMode:e_ptpostprocess_none];
    [PTColorDefaults setDefaultColor:[UIColor greenColor] forAnnotType:PTExtendedAnnotTypeLine attribute:ATTRIBUTE_STROKE_COLOR colorPostProcessMode:e_ptpostprocess_none];
    NSLog(@"toolManagerToolChanged3");
    PTTool *tool = toolManager.tool;
    
    const BOOL backToPan = tool.backToPanToolAfterUse;
    
    [super toolManagerToolChanged:toolManager];
    
    if (tool.backToPanToolAfterUse != backToPan) {
        tool.backToPanToolAfterUse = backToPan;
    }
}

- (void)toolManager:(PTToolManager *)toolManager didSelectAnnotation:(PTAnnot *)annotation onPageNumber:(unsigned long)pageNumber
{
    NSMutableArray<PTAnnot *> *annotations = [NSMutableArray array];
    if ([self.toolManager.tool isKindOfClass:[PTAnnotEditTool class]]) {
        PTAnnotEditTool *annotEdit = (PTAnnotEditTool *)self.toolManager.tool;
        if (annotEdit.selectedAnnotations.count > 0) {
            [annotations addObjectsFromArray:annotEdit.selectedAnnotations];
        }
    } else if (self.toolManager.tool.currentAnnotation) {
        [annotations addObject:self.toolManager.tool.currentAnnotation];
    }
    
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewController:didSelectAnnotations:onPageNumber:)]) {
        [self.delegate rnt_documentViewController:self didSelectAnnotations:[annotations copy] onPageNumber:(int)pageNumber];
    }
}

- (BOOL)toolManager:(PTToolManager *)toolManager shouldShowMenu:(UIMenuController *)menuController forAnnotation:(PTAnnot *)annotation onPageNumber:(unsigned long)pageNumber
{
    if ([toolManager.tool isKindOfClass:[PTAnnotEditTool class]]) {
           // Remove the annotation creation menu items.
        menuController.menuItems = menuController.menuItems;
        [menuController setMenuItems:[self removeAnnotationMenuItems:menuController.menuItems]];
        [menuController setMenuItems:[self addAnnotationMenuItems:menuController.menuItems withAccess:(PTAnnot *)annotation]];
        [menuController setMenuItems:[self updateAnnotationMenuItems:menuController.menuItems]];
        NSLog(@"select annotation call4%@",menuController.menuItems);
        
           //return YES;
       }
    
    BOOL result = [super toolManager:toolManager shouldShowMenu:menuController forAnnotation:annotation onPageNumber:pageNumber];
    if (!result) {
        return NO;
    }
    
    BOOL showMenu = YES;
    if (annotation) {
        if ([self.delegate respondsToSelector:@selector(rnt_documentViewController:
                                                        filterMenuItemsForAnnotationSelectionMenu:
                                                        forAnnotation:)]) {
            showMenu = [self.delegate rnt_documentViewController:self
                       filterMenuItemsForAnnotationSelectionMenu:menuController
                                                   forAnnotation:annotation];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(rnt_documentViewController:
                                                        filterMenuItemsForLongPressMenu:)]) {
            showMenu = [self.delegate rnt_documentViewController:self
                                 filterMenuItemsForLongPressMenu:menuController];
        }
    }
    
    return showMenu;
}

- (NSArray<UIMenuItem *> *)updateAnnotationMenuItems:(NSArray<UIMenuItem *> *)items {
    NSMutableArray<UIMenuItem *> *updatedItems = [items mutableCopy];
    
    // Define the title of the menu item you want to change.
    NSString *itemToChangeTitle = PTLocalizedString(@"Style", nil);
    // Define the new title for the menu item.
    NSString *newItemTitle = @"Edit ";
    
    // Find the index of the menu item with the specified title.
    NSUInteger index = [updatedItems indexOfObjectPassingTest:^BOOL(UIMenuItem *menuItem, NSUInteger idx, BOOL *stop) {
        return [menuItem.title isEqualToString:itemToChangeTitle];
    }];
    
    // Check if the menu item was found.
    if (index != NSNotFound) {
        // Update the title of the menu item.
        UIMenuItem *menuItem = updatedItems[index];
        menuItem.title = newItemTitle;
        [updatedItems replaceObjectAtIndex:index withObject:menuItem];
    }
    
    return [updatedItems copy];
}

- (NSArray<UIMenuItem *> *)removeAnnotationMenuItems:(NSArray<UIMenuItem *> *)items {
    NSLog(@"removeAnnotation call");
    NSArray<NSString *> *stringsToRemove = @[
        PTLocalizedString(@"Note", nil),
        PTLocalizedString(@"Flatten", nil),
        PTLocalizedString(@"Duplicate", nil),
        PTLocalizedString(@"Copy", nil),
        PTLocalizedString(@"Edit", nil),
        PTLocalizedString(@"Make Public", nil),
        PTLocalizedString(@"Set Private", nil),
    ];
    
    // Filter out menu items with titles matching specified strings.
    return [items objectsAtIndexes:[items indexesOfObjectsPassingTest:^BOOL(UIMenuItem *menuItem, NSUInteger idx, BOOL *stop) {
        return ![stringsToRemove containsObject:menuItem.title];
    }]];
}



- (void) handleSetAnnotationAccess:(void(^)(void))handler {
//    PTAnnot* annotation = self.toolManager.tool.currentAnnotation;
//    NSString *annotationAccess = [annotation GetCustomData:@"access"];
//    NSLog(@"handle 1 %@", annotationAccess);
//    if ([annotationAccess isEqualToString:@"private"]) {
//        [annotation SetCustomData:@"access" value:@"public"];
//    } else if ([annotationAccess isEqualToString:@"public"]) {
//      [annotation SetCustomData:@"access" value:@"private"];
//    }
//    NSString *annotationAccesas = [annotation GetCustomData:@"access"];
//    NSLog(@"handle 2 %@", annotationAccesas);
}


- (NSArray<UIMenuItem *> *)addAnnotationMenuItems:(NSArray<UIMenuItem *> *)items withAccess:(PTAnnot *)annotation {
    NSMutableArray<UIMenuItem *> *newItems = [items mutableCopy];
    NSString *annotationAccess = [annotation GetCustomData:@"access"];
    // Add new menu items to the popup based on the access.
    BOOL publicMenuItemExists = NO;
      BOOL privateMenuItemExists = NO;
      
      // Check if the menu already contains items with the titles "Make Public" and "Set Private"
      for (UIMenuItem *item in newItems) {
          if ([item.title isEqualToString:@"Make Public"]) {
              publicMenuItemExists = YES;
          } else if ([item.title isEqualToString:@"Set Private"]) {
              privateMenuItemExists = YES;
          }
      }
      
      // Add new menu items to the popup based on the access, if they don't already exist
      if ([annotationAccess isEqualToString:@"private"] && !publicMenuItemExists) {
          UIMenuItem *publicMenuItem = [[UIMenuItem alloc] initWithTitle:@"Make Public" action:@selector(handleSetAnnotationAccess:)];
          [newItems insertObject:publicMenuItem atIndex:1]; // Insert at index 1
      } else if ([annotationAccess isEqualToString:@"public"] && !privateMenuItemExists) {
          UIMenuItem *privateMenuItem = [[UIMenuItem alloc] initWithTitle:@"Set Private" action:@selector(handleSetAnnotationAccess:)];
          [newItems insertObject:privateMenuItem atIndex:1]; // Insert at index 1
      }
    
    return [newItems copy];
}

- (BOOL)toolManager:(PTToolManager *)toolManager shouldHandleLinkAnnotation:(PTAnnot *)annotation orLinkInfo:(PTLinkInfo *)linkInfo onPageNumber:(unsigned long)pageNumber
{
    BOOL result = [super toolManager:toolManager shouldHandleLinkAnnotation:annotation orLinkInfo:linkInfo onPageNumber:pageNumber];
    if (!result) {
        return NO;
    }
    
    if ([self.delegate respondsToSelector:@selector(toolManager:shouldHandleLinkAnnotation:orLinkInfo:onPageNumber:)]) {
        return [self.delegate toolManager:toolManager shouldHandleLinkAnnotation:annotation orLinkInfo:linkInfo onPageNumber:pageNumber];
    }
    
    return YES;
}

- (void)toolManager:(nonnull PTToolManager *)toolManager pageMovedFromPageNumber:(int)oldPageNumber toPageNumber:(int)newPageNumber;
{
    [super toolManager:toolManager pageMovedFromPageNumber:oldPageNumber toPageNumber:newPageNumber];
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerPageDidMove:pageMovedFromPageNumber:toPageNumber:)]) {
        [self.delegate rnt_documentViewControllerPageDidMove:self pageMovedFromPageNumber:oldPageNumber toPageNumber:newPageNumber];
    }
}

- (void)toolManager:(PTToolManager *)toolManager pageAddedForPageNumber:(int)pageNumber
{
    [super toolManager:toolManager pageAddedForPageNumber:pageNumber];
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerPageAdded:pageNumber:)]) {
        [self.delegate rnt_documentViewControllerPageAdded:self pageNumber:pageNumber];
    }
}

- (void)toolManager:(PTToolManager *)toolManager pageRemovedForPageNumber:(int)pageNumber
{
    [super toolManager:toolManager pageRemovedForPageNumber:pageNumber];
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerPageRemoved:pageNumber:)]) {
        [self.delegate rnt_documentViewControllerPageRemoved:self pageNumber:pageNumber];
    }
}

- (void)toolManager:(PTToolManager *)toolManager didRotatePagesForPageNumbers:(NSIndexSet *)pageNumbers
{
    [super toolManager:toolManager didRotatePagesForPageNumbers:pageNumbers];
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerDidRotatePages:forPageNumbers:)]) {
        [self.delegate rnt_documentViewControllerDidRotatePages:self forPageNumbers:pageNumbers];
    }
}

#pragma mark - <PTPDFViewCtrlDelegate>

- (void)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl onSetDoc:(PTPDFDoc *)doc
{
    [super pdfViewCtrl:pdfViewCtrl onSetDoc:doc];
    
    if (self.local && !self.documentLoaded) {
        self.needsDocumentLoaded = YES;
    }
    else if (!self.local && !self.documentLoaded && self.needsRemoteDocumentLoaded) {
        self.needsDocumentLoaded = YES;
    }
    else if (!self.local && !self.documentLoaded && self.coordinatedDocument.fileURL) {
        self.needsDocumentLoaded = YES;
    }
}

- (void)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl downloadEventType:(PTDownloadedType)type pageNumber:(int)pageNum message:(NSString *)message
{
    if (type == e_ptdownloadedtype_finished && !self.documentLoaded) {
        self.needsRemoteDocumentLoaded = YES;
    }
    
    [super pdfViewCtrl:pdfViewCtrl downloadEventType:type pageNumber:pageNum message:message];
}

- (void)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl pdfScrollViewDidScroll:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerDidScroll:)]) {
        [self.delegate rnt_documentViewControllerDidScroll:self];
    }
}

- (void)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl pdfScrollViewDidZoom:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerDidZoom:)]) {
        [self.delegate rnt_documentViewControllerDidZoom:self];
    }
}

- (void)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl pdfScrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale
{
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerDidFinishZoom:)]) {
        [self.delegate rnt_documentViewControllerDidFinishZoom:self];
    }
}

- (void)pdfViewCtrlOnLayoutChanged:(PTPDFViewCtrl *)pdfViewCtrl
{
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerLayoutDidChange:)]) {
        [self.delegate rnt_documentViewControllerLayoutDidChange:self];
    }
}

- (void)pdfViewCtrlTextSearchStart:(PTPDFViewCtrl *)pdfViewCtrl
{
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerTextSearchDidStart:)]) {
        [self.delegate rnt_documentViewControllerTextSearchDidStart:self];
    }
}

- (void)pdfViewCtrl:(PTPDFViewCtrl *)pdfViewCtrl textSearchResult:(PTSelection *)selection
{
    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerTextSearchDidFindResult:
                                                    selection:)]) {
        [self.delegate rnt_documentViewControllerTextSearchDidFindResult:self
                                                          selection:selection];
    }
}

- (void)outlineViewControllerDidCancel:(PTOutlineViewController *)outlineViewController
{
    [outlineViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)annotationViewControllerDidCancel:(PTAnnotationViewController *)annotationViewController
{
    [annotationViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)bookmarkViewControllerDidCancel:(PTBookmarkViewController *)bookmarkViewController
{
    [bookmarkViewController dismissViewControllerAnimated:YES completion:nil];
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
    BOOL keyboardShortcutsEnabled = YES;

    if ([self.delegate respondsToSelector:@selector(rnt_documentViewControllerAreKeyboardShortcutsEnabled:)]) {
        keyboardShortcutsEnabled = [self.delegate rnt_documentViewControllerAreKeyboardShortcutsEnabled:self];
    }

    if (keyboardShortcutsEnabled) {
        return [super keyCommands];
    }

    return nil;
}

@end
