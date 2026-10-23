// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'fBooks';

  @override
  String get library => '书库';

  @override
  String get collections => '书单';

  @override
  String get plugins => '插件';

  @override
  String get settings => '设置';

  @override
  String get system => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get close => '关闭';

  @override
  String get minimizeWindow => '最小化窗口';

  @override
  String get maximizeWindow => '最大化窗口';

  @override
  String get restoreWindow => '还原窗口';

  @override
  String get closeWindow => '关闭窗口';

  @override
  String get retry => '重试';

  @override
  String get remove => '移除';

  @override
  String get add => '添加';

  @override
  String get back => '返回';

  @override
  String get next => '下一步';

  @override
  String get previous => '上一步';

  @override
  String get done => '完成';

  @override
  String get noItems => '暂无内容';

  @override
  String unableToLoad(String error) {
    return '无法加载：$error';
  }

  @override
  String booksCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '共 $count 本书',
      zero: '暂无书籍',
    );
    return '$_temp0';
  }

  @override
  String collectionsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '共 $count 个自建书单',
      zero: '暂无自建书单',
    );
    return '$_temp0';
  }

  @override
  String get language => '语言';

  @override
  String get languageDescription => '跟随设备语言，或选择应用语言。';

  @override
  String get languageSystem => '系统默认';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get appearance => '外观';

  @override
  String get colorMode => '颜色模式';

  @override
  String get colorModeDescription => '跟随系统，或固定使用一种阅读环境。';

  @override
  String get about => '关于';

  @override
  String get reading => '阅读';

  @override
  String get localLibrary => '本地书库';

  @override
  String get comicReadingMode => '漫画阅读模式';

  @override
  String get comicReadingModeDescription => '可在漫画阅读器工具栏选择方向与双页显示。';

  @override
  String get appDescription => '一款本地优先的漫画和电子书阅读器。';

  @override
  String get version => '版本';

  @override
  String get newCollection => '新建书单';

  @override
  String get yourLists => '你的书单';

  @override
  String get createdCollections => '自建书单';

  @override
  String get collectionActions => '书单操作';

  @override
  String get addBooks => '添加书籍';

  @override
  String get editCollection => '编辑书单';

  @override
  String get deleteCollection => '删除书单';

  @override
  String get collectionName => '书单名称';

  @override
  String get collectionNameHint => '为书单命名';

  @override
  String get collectionDescription => '描述';

  @override
  String get collectionDescriptionHint => '可选的书单说明';

  @override
  String get createCollection => '创建书单';

  @override
  String get saveCollection => '保存书单';

  @override
  String get emptyCollectionsTitle => '创建你的第一个书单';

  @override
  String get emptyCollectionsDescription => '把想放在一起的书分组管理。';

  @override
  String get emptyCollectionTitle => '这个书单还是空的';

  @override
  String get emptyCollectionDescription => '从书库中添加书籍后即可开始阅读。';

  @override
  String get startReading => '开始阅读';

  @override
  String get manageBooks => '管理书籍';

  @override
  String get removeBookFromCollection => '从书单中移除';

  @override
  String get addBookToCollection => '添加到书单';

  @override
  String get libraryEmptyTitle => '你的书库还是空的';

  @override
  String get libraryEmptyDescription => '导入 CBZ、EPUB、PDF 或 TXT 文件后即可开始阅读。';

  @override
  String get importBooks => '导入书籍';

  @override
  String get importingBooks => '正在导入…';

  @override
  String get searchBooks => '搜索书籍';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get allSources => '全部来源';

  @override
  String get localSource => '本地';

  @override
  String get opdsSource => 'OPDS';

  @override
  String get allFormats => '全部格式';

  @override
  String get allPublications => '全部';

  @override
  String get ebookFormat => '电子书';

  @override
  String get enterFullScreen => '进入全屏';

  @override
  String get exitFullScreen => '退出全屏';

  @override
  String get comicFormat => '漫画';

  @override
  String get epubFormat => 'EPUB';

  @override
  String get textFormat => '文本';

  @override
  String get sortByTitleAscending => '书名：A–Z';

  @override
  String get sortByTitleDescending => '书名：Z–A';

  @override
  String get noMatchingBooks => '没有匹配的书籍';

  @override
  String get noMatchingBooksDescription => '试着调整搜索条件或筛选器。';

  @override
  String get libraryActions => '书库操作';

  @override
  String get openDetails => '打开详情';

  @override
  String get removeFromLibrary => '从书库中移除';

  @override
  String get openReader => '打开阅读器';

  @override
  String lastRead(String value) {
    return '最近阅读：$value';
  }

  @override
  String get notReadYet => '尚未阅读';

  @override
  String get unknownRoute => '该页面不存在。';

  @override
  String get backToLibrary => '返回书库';

  @override
  String get opdsRetryCatalog => '重试加载目录';

  @override
  String get opdsCatalogActions => '目录操作';

  @override
  String get editCatalog => '编辑目录';

  @override
  String get removeCatalog => '移除目录';

  @override
  String get browse => '浏览';

  @override
  String get editOpdsCatalog => '编辑 OPDS 目录';

  @override
  String get catalogName => '目录名称';

  @override
  String get catalogUrl => '目录网址';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get validCatalogCredentialsRequired => '请输入有效的网址和完整凭据。';

  @override
  String get removeCatalogTitle => '移除目录？';

  @override
  String removeCatalogDescription(String name) {
    return '要从此设备移除 $name 吗？已下载的出版物会保留在书库中。';
  }

  @override
  String get catalogHasPublications => '请先移除此目录已下载的出版物。';

  @override
  String get cancelDownload => '取消下载';

  @override
  String get downloadToLibrary => '下载到书库或刷新元数据';

  @override
  String publicationAddedToLibrary(String title) {
    return '已将 $title 添加到书库。';
  }

  @override
  String get downloadCancelled => '已取消下载。';

  @override
  String unableToDownloadPublication(String error) {
    return '无法下载出版物：$error';
  }

  @override
  String get readingSettings => '阅读设置';

  @override
  String get closeSettings => '关闭设置';

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String pageProgress(int current, int total) {
    return '第 $current / $total 页';
  }

  @override
  String get readingMode => '阅读模式';

  @override
  String get textPagedMode => '左右翻页';

  @override
  String get textScrollMode => '连续滚动';

  @override
  String get doublePageSpread => '双页显示';

  @override
  String get doublePageSpreadDescription => '在横向模式下一次显示两页。';

  @override
  String get readerEmptyTitle => '没有可读内容';

  @override
  String get readerEmptyDescription => '此出版物没有可阅读的内容。';

  @override
  String get unableToOpenComic => '无法打开此漫画';

  @override
  String unableToOpenPublication(String error) {
    return '无法打开此出版物。\n$error';
  }

  @override
  String get tableOfContents => '目录';

  @override
  String get closeTableOfContents => '关闭目录';

  @override
  String get previousChapter => '上一章';

  @override
  String get nextChapter => '下一章';

  @override
  String chapterProgress(int current, int total) {
    return '第 $current / $total 章';
  }

  @override
  String unableToLoadChapter(String error) {
    return '无法加载本章。\n$error';
  }

  @override
  String get textSize => '字体大小';

  @override
  String get lineHeight => '行高';

  @override
  String get pageMargins => '页边距';

  @override
  String get readerAppearance => '外观';

  @override
  String get sepia => '护眼色';

  @override
  String get pluginTitle => '内置集成';

  @override
  String get pluginDescription => 'Fbooks 以内置、本地优先的方式提供阅读来源。';

  @override
  String get opdsPluginTitle => 'OPDS 目录';

  @override
  String get opdsPluginDescription => '浏览兼容目录并下载可阅读的出版物。';

  @override
  String get localFilesPluginTitle => '本地文件';

  @override
  String get localFilesPluginDescription => '导入并阅读储存在此设备上的文件。';

  @override
  String get notFoundTitle => '该页面不在你的书库中。';

  @override
  String get notFoundDescription => '返回书库并选择一本书继续阅读。';

  @override
  String notFoundRouteDescription(String routeName) {
    return '“$routeName”不可用。请返回书库并选择一本书继续阅读。';
  }

  @override
  String get enabled => '已启用';

  @override
  String get notAvailable => '不可用';

  @override
  String get pluginsDescription => '内置能力均经审查，并在设备上配合你的书库运行。';

  @override
  String get localFilesDescription => '导入并阅读储存在此设备上的 CBZ、EPUB、PDF 和 TXT 文件。';

  @override
  String localLibraryBookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '本地书库有 $count 本书',
      zero: '本地书库暂无书籍',
    );
    return '$_temp0';
  }

  @override
  String get opdsCatalogues => 'OPDS 目录';

  @override
  String get opdsCataloguesDescription => '浏览 OPDS 1 和 OPDS 2 目录，并将可阅读书籍添加到书库。';

  @override
  String get configureCatalogues => '可从书库工具栏配置目录';

  @override
  String get thirdPartyExtensions => '第三方扩展';

  @override
  String get thirdPartyExtensionsDescription => '未安装外部扩展。fBooks 不加载未经审查的阅读器代码。';

  @override
  String get thirdPartyExtensionsDetail => '插件 API 有意不纳入当前本地优先里程碑';

  @override
  String get localPdfRequired => '需要本地 PDF 文件。';

  @override
  String get pdfFileMissing => '导入的 PDF 文件不存在。';

  @override
  String unableToLoadOpdsCatalog(String error) {
    return '无法加载 OPDS 目录。\\n$error';
  }

  @override
  String get noAuthorMetadata => '没有作者元数据';

  @override
  String get usernameOptional => '用户名（可选）';

  @override
  String get passwordOptional => '密码（可选）';

  @override
  String unableToLoadLibrary(String error) {
    return '无法加载书库：$error';
  }

  @override
  String get addLocalPublications => '添加本地出版物';

  @override
  String get connectOpdsCatalog => '连接 OPDS 目录';

  @override
  String get browseOpdsCatalogs => '浏览 OPDS 目录';

  @override
  String get connect => '连接';

  @override
  String get validHttpCatalogUrlRequired => '请输入有效的 HTTP(S) 目录网址。';

  @override
  String get usernameAndPasswordRequired => '请同时输入用户名和密码。';

  @override
  String get noOpdsCatalogs => '尚未连接 OPDS 目录。';

  @override
  String get opdsCatalogs => 'OPDS 目录';

  @override
  String get yourLibrary => '你的书库';

  @override
  String get libraryWelcome => '你的书库将在这里显示。';

  @override
  String get libraryWelcomeDescription => '先导入本地出版物或连接 OPDS 来源。';

  @override
  String get searchLibrary => '搜索书库';

  @override
  String get filterSource => '筛选来源';

  @override
  String get filterFormat => '筛选格式';

  @override
  String get sortPublications => '排序出版物';

  @override
  String get noMatchingPublications => '没有匹配的出版物';

  @override
  String get noMatchingPublicationsDescription => '请尝试其他书名、作者、来源或格式。';

  @override
  String get publicationDetails => '出版物详情';

  @override
  String get collapseCollections => '收起书单';

  @override
  String get expandCollections => '展开书单';

  @override
  String importSummary(int imported, int duplicates, int unsupported) {
    return '已添加 $imported 项，$duplicates 项已在书库中，$unsupported 项不受支持。';
  }

  @override
  String unableToAddPublications(String error) {
    return '无法添加出版物：$error';
  }

  @override
  String get connectOpds => '连接 OPDS';
}
