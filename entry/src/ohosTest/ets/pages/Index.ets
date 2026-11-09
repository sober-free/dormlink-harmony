@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('DormLink 单元测试入口')
        .fontSize(20)
        .fontColor('#E6F1FB')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#101C2B')
  }
}
