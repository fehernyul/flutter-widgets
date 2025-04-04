import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_core/localizations.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../grid_common/row_column_index.dart';
import '../grouping/grouping.dart';
import '../helper/callbackargs.dart';
import '../helper/datagrid_configuration.dart';
import '../helper/datagrid_helper.dart' as grid_helper;
import '../helper/datagrid_helper.dart';
import '../helper/enums.dart';
import '../runtime/column.dart';
import '../runtime/generator.dart';
import '../sfdatagrid.dart';
import 'rendering_widget.dart';

/// A widget which displays in the cells.
class GridCell extends StatefulWidget {
  /// Creates the [GridCell] for [SfDataGrid] widget.
  const GridCell(
      {required Key key,
      required this.dataCell,
      required this.isDirty,
      required this.backgroundColor,
      required this.child,
      required this.dataGridStateDetails})
      : super(key: key);

  /// Holds the information required to display the cell.
  final DataCellBase dataCell;

  /// The [child] contained by the [GridCell].
  final Widget child;

  /// The color to paint behind the [child].
  final Color backgroundColor;

  /// Decides whether the [GridCell] should be refreshed when [SfDataGrid] is
  /// rebuild.
  final bool isDirty;

  /// Holds the [DataGridStateDetails].
  final DataGridStateDetails dataGridStateDetails;

  @override
  State<StatefulWidget> createState() => _GridCellState();
}

class _GridCellState extends State<GridCell> {
  late PointerDeviceKind _kind;
  Timer? tapTimer;

  DataGridStateDetails get dataGridStateDetails => widget.dataGridStateDetails;

  bool _isDoubleTapEnabled(DataGridConfiguration dataGridConfiguration) =>
      dataGridConfiguration.onCellDoubleTap != null ||
      (dataGridConfiguration.allowEditing &&
          dataGridConfiguration.editingGestureType ==
              EditingGestureType.doubleTap);

  Future<void> _handleOnTapDown(
      TapDownDetails details, bool isSecondaryTapDown) async {
    _kind = details.kind!;
    final DataCellBase dataCell = widget.dataCell;
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();

    // Clear editing when tap on the stacked header cell.
    if (widget.dataCell.cellType == CellType.stackedHeaderCell &&
        dataGridConfiguration.currentCell.isEditing) {
      await dataGridConfiguration.currentCell
          .onCellSubmit(dataGridConfiguration);
    }

    if (_isDoubleTapEnabled(dataGridConfiguration)) {
      _handleDoubleTapOnEditing(
          dataGridConfiguration, dataCell, details, isSecondaryTapDown);
    }
  }

  void _handleDoubleTapOnEditing(DataGridConfiguration dataGridConfiguration,
      DataCellBase dataCell, TapDownDetails details, bool isSecondaryTapDown) {
    if (tapTimer != null && tapTimer!.isActive) {
      tapTimer!.cancel();
    } else {
      tapTimer?.cancel();
      // 190 millisecond to satisfies all desktop touchpad double-tap
      // action
      tapTimer = Timer(const Duration(milliseconds: 190), () {
        if (dataGridConfiguration.allowEditing && dataCell.isEditing) {
          tapTimer?.cancel();
          return;
        }
        _handleOnTapUp(
            isSecondaryTapDown: isSecondaryTapDown,
            tapDownDetails: details,
            tapUpDetails: null,
            dataGridConfiguration: dataGridConfiguration,
            dataCell: dataCell,
            kind: _kind);
        tapTimer?.cancel();
      });
    }
  }

  Widget _wrapInsideGestureDetector() {
    final DataCellBase dataCell = widget.dataCell;
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    // Check the DoubleTap is enabled
    // If its enable, we have to ignore the onTapUp and we need to handle both
    // tap and double tap in onTap itself to avoid the delay on double tap
    // callback
    final bool isDoubleTapEnabled = _isDoubleTapEnabled(dataGridConfiguration);
    return GestureDetector(
      onTapUp: isDoubleTapEnabled
          ? null
          : (TapUpDetails details) {
              _handleOnTapUp(
                  tapUpDetails: details,
                  tapDownDetails: null,
                  dataGridConfiguration: dataGridConfiguration,
                  dataCell: dataCell,
                  kind: _kind);
            },
      onTapDown: (TapDownDetails details) => _handleOnTapDown(details, false),
      onTap: isDoubleTapEnabled
          ? () {
              if (tapTimer != null && !tapTimer!.isActive) {
                _handleOnDoubleTap(
                    dataCell: dataCell,
                    dataGridConfiguration: dataGridConfiguration);
              }
            }
          : null,
      onTapCancel: () {
        if (tapTimer != null && tapTimer!.isActive) {
          tapTimer?.cancel();
        }
      },
      onSecondaryTapUp: (TapUpDetails details) {
        _handleOnSecondaryTapUp(
            tapUpDetails: details,
            dataGridConfiguration: dataGridConfiguration,
            dataCell: dataCell,
            kind: _kind);
      },
      onSecondaryTapDown: (TapDownDetails details) =>
          _handleOnTapDown(details, true),
      child: _wrapInsideContainer(),
    );
  }

  // ez (csak) az adatcellákat rajzolja ki - gabor 2024.09.23 - tvg
  Widget _wrapInsideContainer() {
    return Container(
      key: widget.key,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          border: _getCellBorder(dataGridStateDetails(), widget.dataCell)),
      alignment: Alignment.center,
      child: _wrapInsideCellContainer(
        dataGridConfiguration: dataGridStateDetails(),
        child: widget.child,
        dataCell: widget.dataCell,
        key: widget.key!,
        backgroundColor: widget.backgroundColor,
      ), // TODO: TVG current cell backgound color beállítása - gabor 2024.09.23
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridCellRenderObjectWidget(
      key: widget.key,
      dataCell: widget.dataCell,
      isDirty: widget.isDirty,
      dataGridStateDetails: dataGridStateDetails,
      child: _wrapInsideGestureDetector(),
    );
  }

  @override
  void dispose() {
    super.dispose();
    if (tapTimer != null) {
      tapTimer = null;
    }
  }
}

/// A widget which displays in the header cells.
class GridHeaderCell extends StatefulWidget {
  /// Creates the [GridHeaderCell] for [SfDataGrid] widget.
  const GridHeaderCell(
      {required Key key,
      required this.dataCell,
      required this.backgroundColor,
      required this.isDirty,
      required this.child,
      required this.dataGridStateDetails})
      : super(key: key);

  /// Holds the information required to display the cell.
  final DataCellBase dataCell;

  /// The [child] contained by the [GridCell].
  final Widget child;

  /// The color to paint behind the [child].
  final Color backgroundColor;

  /// Decides whether the [GridCell] should be refreshed when [SfDataGrid] is
  /// rebuild.
  final bool isDirty;

  /// Holds the [DataGridStateDetails].
  final DataGridStateDetails dataGridStateDetails;

  @override
  State<StatefulWidget> createState() => _GridHeaderCellState();

  @override
  GridHeaderCellElement createElement() {
    return GridHeaderCellElement(this, dataCell.gridColumn!);
  }
}

/// An instantiation of a [GridHeaderCell] widget at a particular location in the tree.
class GridHeaderCellElement extends StatefulElement {
  /// Creates the [GridHeaderCellElement] for [GridHeaderCell] widget.
  GridHeaderCellElement(GridHeaderCell gridHeaderCell, this.column)
      : super(gridHeaderCell);

  /// A GridColumn which displays in the header cells.
  GridColumn column;

  @override
  void update(covariant GridHeaderCell newWidget) {
    super.update(newWidget);
    if (column != newWidget.dataCell.gridColumn) {
      column = newWidget.dataCell.gridColumn!;
    }
  }
}

class _GridHeaderCellState extends State<GridHeaderCell> {
  DataGridSortDirection? _sortDirection;
  Color _sortIconColor = Colors.transparent;
  Color _sortIconHoverColor = Colors.transparent;
  int _sortNumber = -1;
  Color _sortNumberBackgroundColor = Colors.transparent;
  Color _sortNumberTextColor = Colors.transparent;
  late PointerDeviceKind _kind;
  late Widget? _sortIcon;
  late IconData? _sortIconData;
  late IconData? _sortIconDataUnsorted;
  late double? _sortIconDataIconSize;
  late Function? _getSortIconData;
  bool isHovered = false;

  DataGridStateDetails get dataGridStateDetails => widget.dataGridStateDetails;

  void _handleOnTapUp(TapUpDetails tapUpDetails) {
    final DataCellBase dataCell = widget.dataCell;
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    // Clear editing when tap on the header cell
    _clearEditing(dataGridConfiguration);
    if (dataGridConfiguration.onCellTap != null) {
      final DataGridCellTapDetails details = DataGridCellTapDetails(
          rowColumnIndex:
              RowColumnIndex(dataCell.rowIndex, dataCell.columnIndex),
          column: dataCell.gridColumn!,
          globalPosition: tapUpDetails.globalPosition,
          localPosition: tapUpDetails.localPosition,
          kind: _kind);
      dataGridConfiguration.onCellTap!(details);
    }

    dataGridConfiguration.dataGridFocusNode?.requestFocus();
    if (dataGridConfiguration.sortingGestureType == SortingGestureType.tap ||
        dataGridConfiguration.sortingGestureType ==
            SortingGestureType.tvgStyle) {
      _sort(dataCell);
    }
  }

  void _handleOnDoubleTap() {
    final DataCellBase dataCell = widget.dataCell;
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    // Clear editing when tap on the header cell
    _clearEditing(dataGridConfiguration);
    if (dataGridConfiguration.onCellDoubleTap != null) {
      final DataGridCellDoubleTapDetails details = DataGridCellDoubleTapDetails(
          rowColumnIndex:
              RowColumnIndex(dataCell.rowIndex, dataCell.columnIndex),
          column: dataCell.gridColumn!);
      dataGridConfiguration.onCellDoubleTap!(details);
    }

    dataGridConfiguration.dataGridFocusNode?.requestFocus();
    if (dataGridConfiguration.sortingGestureType ==
        SortingGestureType.doubleTap) {
      _sort(dataCell);
    }
  }

  void _handleOnSecondaryTapUp(TapUpDetails tapUpDetails) {
    final DataCellBase dataCell = widget.dataCell;
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    // Clear editing when tap on the header cell
    _clearEditing(dataGridConfiguration);
    if (dataGridConfiguration.onCellSecondaryTap != null) {
      final DataGridCellTapDetails details = DataGridCellTapDetails(
          rowColumnIndex:
              RowColumnIndex(dataCell.rowIndex, dataCell.columnIndex),
          column: dataCell.gridColumn!,
          globalPosition: tapUpDetails.globalPosition,
          localPosition: tapUpDetails.localPosition,
          kind: _kind);
      dataGridConfiguration.onCellSecondaryTap!(details);
    }
  }

  void _handleOnTapDown(TapDownDetails details) {
    _kind = details.kind!;
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    // Clear editing when tap on the header cell
    _clearEditing(dataGridConfiguration);
  }

  /// Helps to clear the editing cell when tap on header cells
  Future<void> _clearEditing(
      DataGridConfiguration dataGridConfiguration) async {
    if (dataGridConfiguration.currentCell.isEditing) {
      await dataGridConfiguration.currentCell
          .onCellSubmit(dataGridConfiguration);
    }
  }

  Widget _wrapInsideGestureDetector() {
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    return GestureDetector(
      onTapUp: dataGridConfiguration.isTvgGrid
          ? null
          : (dataGridConfiguration.onCellTap != null ||
                  dataGridConfiguration.sortingGestureType ==
                      SortingGestureType.tap
              ? _handleOnTapUp
              : null),
      onTapDown: _handleOnTapDown,
      onDoubleTap: dataGridConfiguration.onCellDoubleTap != null ||
              dataGridConfiguration.sortingGestureType ==
                  SortingGestureType.doubleTap
          ? _handleOnDoubleTap
          : null,
      onSecondaryTapUp: dataGridConfiguration.onCellSecondaryTap != null
          ? _handleOnSecondaryTapUp
          : null,
      onSecondaryTapDown: _handleOnTapDown,
      child: _wrapInsideContainer(),
    );
  }

  Widget _wrapInsideContainer() {
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    final GridColumn? column = widget.dataCell.gridColumn;

    Widget checkHeaderCellConstraints(Widget child) {
      return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        return _buildHeaderCell(child, _sortDirection, constraints.maxWidth);
      });
    }

    _ensureSortIconVisibility(column!, dataGridConfiguration);

    // ez csak a header-t rajzolja ki - tvg
    Widget child = _wrapInsideCellContainer(
      dataGridConfiguration: dataGridConfiguration,
      child: checkHeaderCellConstraints(widget.child),
      dataCell: widget.dataCell,
      key: widget.key!,
      // backgroundColor: Colors.red,
      backgroundColor: widget.backgroundColor,
    );

    Widget getFeedbackWidget(DataGridConfiguration configuration) {
      return dataGridConfiguration.columnDragFeedbackBuilder != null
          ? dataGridConfiguration.columnDragFeedbackBuilder!(
              context, widget.dataCell.gridColumn!)
          : Container(
              width: widget.dataCell.gridColumn!.actualWidth,
              height: dataGridConfiguration.headerRowHeight,
              decoration: BoxDecoration(
                  color: dataGridConfiguration
                      .dataGridThemeHelper!.feedBackWidgetColor,
                  border: Border.all(
                      color: dataGridConfiguration
                          .dataGridThemeHelper!.gridLineColor!,
                      width: dataGridConfiguration
                          .dataGridThemeHelper!.gridLineStrokeWidth!)),
              child: widget.child);
    }

    Widget buildDraggableHeaderCell(Widget child) {
      final DataGridConfiguration configuration = dataGridStateDetails();
      final bool isWindowsPlatform =
          configuration.columnDragAndDropController.isWindowsPlatform!;
      return Draggable<Widget>(
        onDragStarted: () {
          if (widget.dataCell.cellType != CellType.indentCell) {
            configuration.columnDragAndDropController
                .onPointerDown(widget.dataCell);
          }
        },
        ignoringFeedbackPointer: isWindowsPlatform,
        feedback: MouseRegion(
            cursor: isWindowsPlatform
                ? MouseCursor.defer
                : (dataGridConfiguration.isMacPlatform && !kIsWeb)
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.move,
            child: getFeedbackWidget(configuration)),
        child: child,
      );
    }

    if (dataGridConfiguration.columnDragAndDropController
            .canAllowColumnDragAndDrop() &&
        dataGridConfiguration
            .columnDragAndDropController.canWrapDraggableView &&
        !dataGridConfiguration
            .columnResizeController.canSwitchResizeColumnCursor) {
      child = buildDraggableHeaderCell(child);
    }

    return Container(
        key: widget.key,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            border: _getCellBorder(
              dataGridConfiguration,
              widget.dataCell,
        )),
        child: child);
  }

  @override
  Widget build(BuildContext context) {
    return GridCellRenderObjectWidget(
      key: widget.key,
      dataCell: widget.dataCell,
      isDirty: widget.isDirty,
      dataGridStateDetails: dataGridStateDetails,
      child: _wrapInsideGestureDetector(),
    );
  }

  void _ensureSortIconVisibility(
      GridColumn column, DataGridConfiguration? dataGridConfiguration) {
    if (dataGridConfiguration != null) {
      // -- a grid datasource-jaban a sortedColumns tombben benne van-e a column.columnName altal megahatarozott oszlop (azaz a a kert oszlop-ra van-e rendezes?)
      final SortColumnDetails? sortColumn = dataGridConfiguration
          .source.sortedColumns
          .firstWhereOrNull((SortColumnDetails sortColumn) =>
              sortColumn.name == column.columnName);

      bool hasSubOrder2 = false;

      if (column.getHasSubOrderingFunc != null) {
        hasSubOrder2 = column.getHasSubOrderingFunc!();
      }

      if (sortColumn == null && hasSubOrder2) {
        _sortNumber = -2;
        return;
      }
      // }

      // -- ha van, akkor...
      if (dataGridConfiguration.source.sortedColumns.isNotEmpty &&
          sortColumn != null) {
        //final int sortNumber =
        //    dataGridConfiguration.source.sortedColumns.indexOf(sortColumn) + 1;

        final int sortNumber = sortColumn.sortIndex; // 2023.09.22
        _sortDirection = sortColumn.sortDirection;
        _sortNumberBackgroundColor = dataGridConfiguration
                .dataGridThemeHelper!.sortOrderNumberBackgroundColor ??
            dataGridConfiguration.colorScheme!.onSurface[31]!;
        _sortNumberTextColor =
            (dataGridConfiguration.dataGridThemeHelper!.sortOrderNumberColor ??
                dataGridConfiguration.colorScheme!.onSurface[222])!;
        if (/*dataGridConfiguration.source.sortedColumns.length > 1 && -- akkor is mutassa, ha 1 van! - gabor 2024.01.24*/
            dataGridConfiguration.showSortNumbers) {
          _sortNumber = sortNumber;
        } else {
          _sortNumber = -1;
        }
      } else {
        _sortDirection = null;
        _sortNumber = -1;
      }
    }
  }

  Widget _buildHeaderCell(Widget child, DataGridSortDirection? sortDirection,
      double availableWidth) {
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    final GridColumn gridColumn = widget.dataCell.gridColumn!;
    final bool isSortedColumn = dataGridConfiguration.source.sortedColumns.any(
        (SortColumnDetails element) => element.name == gridColumn.columnName);
    final bool isSortNumberVisible = _sortNumber != 1;

    bool hasSubOrder2 = false;
    if (gridColumn.getHasSubOrderingFunc != null) {
      hasSubOrder2 = gridColumn.getHasSubOrderingFunc!();
    }

    if (((hasSubOrder2 || isSortedColumn) ||
            (gridColumn.allowSorting && dataGridConfiguration.allowSorting)) ||
        (gridColumn.allowFiltering && dataGridConfiguration.allowFiltering)) {
      final double sortIconWidth =
          getSortIconWidth(dataGridConfiguration.columnSizer, gridColumn);
      final double filterIconWidth =
          getFilterIconWidth(dataGridConfiguration.columnSizer, gridColumn);

      if ((sortIconWidth > 0 && sortIconWidth < availableWidth) ||
          (filterIconWidth > 0 && filterIconWidth < availableWidth)) {
        final Map<String, Widget> children = <String, Widget>{};

        if (sortIconWidth > 0 &&
            availableWidth > sortIconWidth + filterIconWidth) {
          _sortIconColor = dataGridConfiguration.dataGridThemeHelper!.sortIconColor ?? Colors.transparent;
          _sortIconHoverColor = dataGridConfiguration.dataGridThemeHelper!.sortIconHoverColor ?? Colors.transparent;
          _sortIcon = dataGridConfiguration.dataGridThemeHelper!.sortIcon;
          _sortIconData = dataGridConfiguration.dataGridThemeHelper!.sortIconData;
          _sortIconDataUnsorted = dataGridConfiguration.dataGridThemeHelper!.sortIconDataUnsorted;
          _sortIconDataIconSize = dataGridConfiguration.dataGridThemeHelper!.sortIconDataIconSize;
          _getSortIconData = dataGridConfiguration.dataGridThemeHelper!.getSortIconData;

          if (_sortDirection != null) {
            if (_sortIcon == null || _sortIcon is Icon || _sortIcon is Builder || _sortIcon is StatefulBuilder) {
              if (_sortNumber != -2) {
                // sima, gyari order ikon
                children['sortIcon'] = _SortIcon(
                  sortDirection: _sortDirection!,
                  sortIconColor: _sortIconColor,
                  sortIconHoverColor: _sortIconHoverColor,
                  sortIconData: _sortIconData,
                  sortIconDataUnsorted: _sortIconDataUnsorted,
                  sortIcon: _sortIcon,
                  sortIconSize: _sortIconDataIconSize,
                  getSortIconData: _getSortIconData,
                  onSortedIconTapDown: _handleOnTapDown,
                  onSortedIconTapUp: _handleOnTapUp,
                );
              }
            } else {
              //ez mikor fut le???
              if (sortDirection == DataGridSortDirection.ascending) {
                children['sortIcon'] =
                    _BuilderSortIconAscending(sortIcon: _sortIcon);
              } else if (sortDirection == DataGridSortDirection.descending) {
                children['sortIcon'] =
                    _BuilderSortIconDescending(sortIcon: _sortIcon);
              }
            }

            if (_sortNumber != 0 && _sortNumber != -1 && _sortNumber != -2) {
              children['sortNumber'] = _getSortNumber();
            }
          } else if (gridColumn.allowSorting && dataGridConfiguration.allowSorting) {
              //Ez fut le első alkalommal utána a _SortIcon fut le
              children['sortIcon'] = _SortIconCore(
                sortDirection: DataGridSortDirection.unsorted,
                getSortIconData: _getSortIconData,
                sortIcon: _sortIcon,
                sortIconData: _sortIconData,
                sortIconDataUnsorted: _sortIconDataUnsorted,
                sortIconColor: _sortIconColor,
                sortIconHoverColor: _sortIconHoverColor,
                sortIconSize: _sortIconDataIconSize,
                onTapDown: _handleOnTapDown,
                onTapUp: _handleOnTapUp,
              );
          }

          // ha van az oszlop alatt subOrderezes, akkor kiteszunk egy plusz ikont IS!
          if (hasSubOrder2) {
            children['subFilterIcon'] = Icon(Icons.swap_vert, color: Colors.green);
          }
        }

        if (filterIconWidth > 0 && availableWidth > filterIconWidth) {
          children['filterIcon'] = _FilterIcon(
            dataGridConfiguration: dataGridConfiguration,
            column: gridColumn,
          );
        }

        bool canShowColumnHeaderIcon() {
          final bool isFilteredColumn = dataGridConfiguration
              .source.filterConditions
              .containsKey(gridColumn.columnName);
          if (dataGridConfiguration.showColumnHeaderIconOnHover &&
              dataGridConfiguration.isDesktop) {
            return isHovered ||
                dataGridConfiguration
                    .dataGridFilterHelper!.isFilterPopupMenuShowing ||
                isFilteredColumn ||
                isSortedColumn;
          } else {
            return true;
          }
        }

        Widget buildHeaderCellIcons(bool isColumnHeaderIconVisible) {
          return Container(
            padding: dataGridConfiguration.columnSizer.iconsOuterPadding,
            child: Center(
              child: isColumnHeaderIconVisible
                  ? Row(
                      children: <Widget>[
                        if (children.containsKey('sortIcon'))
                          children['sortIcon']!,
                        if (children.containsKey('sortNumber'))
                          children['sortNumber']!,
                        if (children.containsKey('filterIcon'))
                          children['filterIcon']!,
                        if (children.containsKey('subFilterIcon'))
                          children['subFilterIcon']!,
                      ],
                    )
                  : const SizedBox(),
            ),
          );
        }

        late Widget headerCell;
        final bool isColumnHeaderIconVisible = canShowColumnHeaderIcon();
        if (gridColumn.sortIconPosition == ColumnHeaderIconPosition.end &&
            gridColumn.filterIconPosition == ColumnHeaderIconPosition.end) {
          headerCell = Row(
            children: <Widget>[
              Flexible(child: Container(child: child)),
              buildHeaderCellIcons(isColumnHeaderIconVisible)
            ],
          );
        } else if (gridColumn.sortIconPosition ==
                ColumnHeaderIconPosition.start &&
            gridColumn.filterIconPosition == ColumnHeaderIconPosition.start) {
          headerCell = Row(
            children: <Widget>[
              buildHeaderCellIcons(isColumnHeaderIconVisible),
              Flexible(child: child),
            ],
          );
        } else if (gridColumn.sortIconPosition ==
                ColumnHeaderIconPosition.end &&
            gridColumn.filterIconPosition == ColumnHeaderIconPosition.start) {
          headerCell = Row(
            children: <Widget>[
              if (isColumnHeaderIconVisible)
                Center(
                  child: children['filterIcon'] ?? const SizedBox(),
                ),
              Flexible(
                child: Container(child: child),
              ),
              if (isColumnHeaderIconVisible)
                Container(
                  padding: dataGridConfiguration.columnSizer.iconsOuterPadding,
                  child: Row(
                    children: <Widget>[
                      Center(
                        child: children['sortIcon'] ?? const SizedBox(),
                      ),
                      if (isSortNumberVisible)
                        Center(child: children['sortNumber']),
                    ],
                  ),
                ),
            ],
          );
        } else {
          headerCell = Row(
            children: <Widget>[
              if (isColumnHeaderIconVisible)
                Container(
                  padding: dataGridConfiguration.columnSizer.iconsOuterPadding,
                  child: Row(
                    children: <Widget>[
                      Center(
                        child: children['sortIcon'] ?? const SizedBox(),
                      ),
                      if (isSortNumberVisible)
                        Center(child: children['sortNumber']),
                    ],
                  ),
                ),
              Flexible(
                child: Container(child: child),
              ),
              if (isColumnHeaderIconVisible)
                Center(
                  child: children['filterIcon'] ?? const SizedBox(),
                ),
            ],
          );
        }

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: headerCell,
        );
      }
    }
    return  Row(
      children: <Widget>[
        Flexible(child: Container(child: child)),
      ]);

  }

  Widget _getSortNumber() {
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();

    if (dataGridConfiguration.dataGridThemeHelper!.getSortOrderNumberWidget!=null){
      return dataGridConfiguration.dataGridThemeHelper!.getSortOrderNumberWidget!(_sortNumber.toString());
    };

    return Center(
      child: Container(
        //alignment: Alignment.center,
        width: 20,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: _sortNumberTextColor,
            width: 2.0,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
              child:Text(
                _sortNumber.toString(),
                style: TextStyle(fontSize: 12, color: _sortNumberTextColor),
              ),
          )
      ),
    );
  }

  void _sort(DataCellBase dataCell) {
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    if (dataCell.dataRow?.rowType == RowType.headerRow &&
        dataCell.dataRow?.rowIndex ==
            grid_helper.getHeaderIndex(dataGridConfiguration)) {
      _makeSort(dataCell);
    }
  }

  int getAllPreviousSortCounter(DataGridSource source) {
    int result = source.getSortedColumnsStartIndex();
    // Print.red('getAllPreviousSortCounter() :: $result', name: 'getAllPreviousSortCounter');
    return result;
  }

  // ez osszeallitja (hozzaad, torol) a datasource.sortedColumns listat
  // plusz matol (2023.09.22) ez kezeli a TvgGrid-et
  Future<void> _makeSort(DataCellBase dataCell) async {
    final DataGridConfiguration dataGridConfiguration = dataGridStateDetails();
    int previousSortCount = 0;

    //End-edit before perform sorting
    if (dataGridConfiguration.currentCell.isEditing) {
      await dataGridConfiguration.currentCell
          .onCellSubmit(dataGridConfiguration, canRefresh: false);
    }

    final GridColumn column = dataCell.gridColumn!;

    if (column.allowSorting && dataGridConfiguration.allowSorting) {
      final String sortColumnName = column.columnName;
      final bool allowMultiSort = true; // ezt ideiglenesen true-ra állítom
      // final bool allowMultiSort = dataGridConfiguration.isMacPlatform
      //     ? (dataGridConfiguration.isCommandKeyPressed && dataGridConfiguration.allowMultiColumnSorting)
      //     : dataGridConfiguration.isDesktop
      //         ? (dataGridConfiguration.isControlKeyPressed && dataGridConfiguration.allowMultiColumnSorting)
      //         : dataGridConfiguration.allowMultiColumnSorting;
      final DataGridSource source = dataGridConfiguration.source;

      final List<SortColumnDetails> sortedColumns = source.sortedColumns;
      if (sortedColumns.isNotEmpty && allowMultiSort) {
        // gabor 2024.01.29 - begin
        previousSortCount =
            getAllPreviousSortCounter(dataGridConfiguration.source);
        // gabor 2024.01.29 - end
        SortColumnDetails? sortedColumn = sortedColumns.firstWhereOrNull(
            (SortColumnDetails sortColumn) =>
                sortColumn.name == sortColumnName);
        if (sortedColumn == null) {
          final SortColumnDetails newSortColumn = SortColumnDetails(
            name: sortColumnName,
            sortDirection: DataGridSortDirection.ascending,
            sortIndex: previousSortCount + 1,
          );
          sortedColumns.add(newSortColumn);
          if (dataGridConfiguration.onSortAdded != null) {
            dataGridConfiguration.onSortAdded!(newSortColumn);
          }
        } else {
          if (sortedColumn.sortDirection == DataGridSortDirection.descending &&
              dataGridConfiguration.allowTriStateSorting) {
            final SortColumnDetails? removedSortColumn =
                sortedColumns.firstWhereOrNull((SortColumnDetails sortColumn) =>
                    sortColumn.name == sortColumnName);
            sortedColumns.remove(removedSortColumn);
            if (dataGridConfiguration.onSortRemoved != null &&
                removedSortColumn != null) {
              dataGridConfiguration.onSortRemoved!(removedSortColumn);
            }
          } else {
            sortedColumn = SortColumnDetails(
              name: sortedColumn.name,
              sortDirection:
                  sortedColumn.sortDirection == DataGridSortDirection.ascending
                      ? DataGridSortDirection.descending
                      : DataGridSortDirection.ascending,
              sortIndex: sortedColumn.sortIndex,
            );
            final SortColumnDetails? removedSortColumn =
                sortedColumns.firstWhereOrNull((SortColumnDetails sortColumn) =>
                    sortColumn.name == sortedColumn!.name);

            sortedColumns
              ..remove(removedSortColumn)
              ..add(sortedColumn);

            // na, mi ilyet nem csinalunk, hogy ha torlunk egy oszlopRendezest, majd beszurjuk ugyanazt az oszlopRendezest csak a masik iranyban, ez egy buzisag. Csak az iranyat kell modositani!
            // if (dataGridConfiguration.onSortRemoved != null && removedSortColumn != null) {
            //   dataGridConfiguration.onSortRemoved!(removedSortColumn);
            // }

            if (dataGridConfiguration.onSortChanged != null) {
              dataGridConfiguration.onSortChanged!(sortedColumn);
            }
          }
        }
      } else {
        // ha NEM allowMultiSort

        // kikeressük, ha az az oszlop, amire éppen rákattintottunk, az benne van-e a "sortedColumns"-ban
        SortColumnDetails? currentSortColumn = sortedColumns.firstWhereOrNull(
            (SortColumnDetails sortColumn) =>
                sortColumn.name == sortColumnName);
        // gabor 2024.01.29 - begin
        previousSortCount =
            1; // ha nem allowMultiSort van, akkor tulajdonképpen mindig csak 1 sorrendezés lesz, és az legyen a 1-es számú! // = getAllPreviousSortCounter(dataGridConfiguration.source);
        // gabor 2024.01.29 - end

        // ha benne van, akkor ...
        if (sortedColumns.isNotEmpty && currentSortColumn != null) {
          if (currentSortColumn.sortDirection ==
                  DataGridSortDirection.descending &&
              dataGridConfiguration.allowTriStateSorting) {
            // ez az, amikor DESC-rről semmire váltunk (azaz töröljük az erre az oszlopra való rendezést)
            sortedColumns.clear();

            if (dataGridConfiguration.onSortRemoved != null) {
              dataGridConfiguration.onSortRemoved!(currentSortColumn);
            }
          } else {
            // ez az, amikor ASC-ról DESC-re váltunk
            currentSortColumn = SortColumnDetails(
              name: currentSortColumn.name,
              sortDirection: currentSortColumn.sortDirection ==
                      DataGridSortDirection.ascending
                  ? DataGridSortDirection.descending
                  : DataGridSortDirection.ascending,
              sortIndex: previousSortCount,
            );

            sortedColumns
              ..clear()
              ..add(currentSortColumn);

            // na, mi ilyet nem csinalunk, hogy ha torlunk egy oszlopRendezest, majd beszurjuk ugyanazt az oszlopRendezest csak a masik iranyban, ez egy buzisag. Csak az iranyat kell modositani!
            // if (dataGridConfiguration.onSortRemoved != null) {
            //   dataGridConfiguration.onSortRemoved!(currentSortColumn);
            // }

            if (dataGridConfiguration.onSortChanged != null) {
              dataGridConfiguration.onSortChanged!(currentSortColumn);
            }
          }
        } else {
          // ez az, amikor a semmiről (még nem volt rendezés erre az oszlopra) ASC-ra váltunk (azaz hozzáadjuk a rendezett oszlopok listájához)
          final SortColumnDetails sortColumn = SortColumnDetails(
            name: sortColumnName,
            sortDirection: DataGridSortDirection.ascending,
            sortIndex:
                1, // previousSortCount + 1, // ha nem allowMultiSort van, akkor tulajdonképpen mindig csak 1 sorrendezés lesz, és az legyen a 1-es számú!
          );
          // ha volt már előzőleg rendezés egy másik oszlopra
          if (sortedColumns.isNotEmpty) {
            if (dataGridConfiguration.onSortChanged != null) {
              dataGridConfiguration.onSortChanged!(sortedColumns[
                  0]); // ez jo bena, de mivel ugyis isNotEmpty, es csak 1 elem lehet benne, ezert remelem ez igy jo lesz
            }
            sortedColumns
              ..clear()
              ..add(sortColumn);
          } else {
            sortedColumns.add(sortColumn);

            if (dataGridConfiguration.onSortAdded != null) {
              dataGridConfiguration.onSortAdded!(sortColumn);
            }
          }
        }
      }

      // ha dataGridConfiguration.dataSourceFromDB, akkor azt biztosan a TVG kezeli mégpedig az "onSortAdded", "onSortChanged", "onSortRemoved" fgv-en belül
      if (!dataGridConfiguration.dataSourceFromDB) {
        // Refreshes the datagrid source and performs sorting based on
        // `DataGridSource.sortedColumns`.
        source.sort();
      }
    }
  }
}

class _BuilderSortIconAscending extends StatelessWidget {
  const _BuilderSortIconAscending({required this.sortIcon});

  final Widget? sortIcon;

  @override
  Widget build(BuildContext context) {
    return sortIcon!;
  }
}

class _BuilderSortIconDescending extends StatelessWidget {
  const _BuilderSortIconDescending({required this.sortIcon});

  final Widget? sortIcon;

  @override
  Widget build(BuildContext context) {
    return sortIcon!;
  }
}

class _SortIcon extends StatefulWidget {
  const _SortIcon({
    required this.sortDirection,
    required this.sortIconColor,
    required this.sortIconHoverColor,
    required this.sortIcon,
    required this.sortIconData,
    required this.sortIconDataUnsorted,
    required this.sortIconSize,
    required this.getSortIconData,
    required this.onSortedIconTapUp,
    required this.onSortedIconTapDown,
  });
  final DataGridSortDirection sortDirection;
  final Color sortIconColor;
  final Color sortIconHoverColor;
  final Widget? sortIcon;
  final IconData? sortIconData;
  final IconData? sortIconDataUnsorted;
  final double? sortIconSize;
  final Function? getSortIconData;
  final GestureTapDownCallback onSortedIconTapDown;
  final GestureTapUpCallback onSortedIconTapUp;

  @override
  _SortIconState createState() => _SortIconState();
}

class _SortIconState extends State<_SortIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _sortingAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _sortingAnimation = Tween<double>(begin: 0.0, end: pi).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    if (widget.sortDirection == DataGridSortDirection.descending) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_SortIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortDirection == DataGridSortDirection.ascending &&
        widget.sortDirection == DataGridSortDirection.descending) {
      _animationController.forward();
    } else if (oldWidget.sortDirection == DataGridSortDirection.descending &&
        widget.sortDirection == DataGridSortDirection.ascending) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // = gabor 2023.07.05 - change sorted icon color to red
    return AnimatedBuilder(
        animation: _animationController,
        builder: (BuildContext context, Widget? child) {
          return Transform.rotate(
              angle: _sortingAnimation.value,
              child:
                  _SortIconCore(
                    getSortIconData: widget.getSortIconData,
                    sortDirection: widget.sortDirection,
                    sortIcon: widget.sortIcon,
                    sortIconData: widget.sortIconData,
                    sortIconDataUnsorted: widget.sortIconDataUnsorted,
                    sortIconColor: widget.sortIconColor,
                    sortIconHoverColor: widget.sortIconHoverColor,
                    sortIconSize: widget.sortIconSize,
                    onTapDown: widget.onSortedIconTapDown,
                    onTapUp: widget.onSortedIconTapUp,
                  ),
              );
        });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class _SortIconCore extends StatefulWidget {
  const _SortIconCore({
    required this.sortDirection,
    required this.sortIconColor,
    required this.sortIconHoverColor,
    required this.sortIcon,
    required this.sortIconData,
    required this.sortIconDataUnsorted,
    required this.sortIconSize,
    required this.getSortIconData,
    required this.onTapDown,
    required this.onTapUp,
  });

  final Widget? sortIcon;
  final IconData? sortIconData;
  final IconData? sortIconDataUnsorted;
  final Color sortIconColor;
  final Color sortIconHoverColor;
  final double? sortIconSize;
  final Function? getSortIconData;
  final DataGridSortDirection sortDirection;
  final GestureTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;

  @override
  State<_SortIconCore> createState() => _SortIconCoreState();
}

class _SortIconCoreState extends State<_SortIconCore> {
  Widget _getSortIcon(bool isHoveredSortIconCore) {
    if (widget.sortIcon!=null) {
      return widget.sortIcon!;
    }

    if (widget.getSortIconData!=null){
      return widget.getSortIconData!.call(widget.sortDirection, isHoveredSortIconCore);
    }

    //mivel úgy is forgatja nem kell megkülönbözetetni
    if ((widget.sortDirection == DataGridSortDirection.ascending) ||  (widget.sortDirection == DataGridSortDirection.descending)) {
      return Icon(widget.sortIconData ?? Icons.arrow_upward,
          color: isHoveredSortIconCore ? widget.sortIconHoverColor : widget.sortIconColor,
          size: widget.sortIconSize ?? 16);
    } else {
      const IconData unsortIconData = IconData(0xe700,fontFamily: 'UnsortIcon', fontPackage: 'syncfusion_flutter_datagrid');
      return Icon(widget.sortIconDataUnsorted ?? unsortIconData,
          color: isHoveredSortIconCore ? widget.sortIconHoverColor : widget.sortIconColor,
          size: widget.sortIconSize ?? 16);
    }
  }

  bool isHovered = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        widget.onTapDown.call(details);
        //
      },
      onTapUp: (TapUpDetails details) {
        widget.onTapUp.call(details);
        //
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: _getSortIcon(isHovered),
        onEnter: (_) {
          setState(() {
            // print('isHovered = true');
            isHovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            // print('isHovered = false');
            isHovered = false;
          });
        },
      ),
    );
  }
}

class _FilterIcon extends StatefulWidget {
  const _FilterIcon(
      {Key? key, required this.column, required this.dataGridConfiguration})
      : super(key: key);

  final GridColumn column;
  final DataGridConfiguration dataGridConfiguration;

  @override
  State<_FilterIcon> createState() => _FilterIconState();
}

class _FilterIconState extends State<_FilterIcon> {
  void onHandleTap(TapUpDetails details, BuildContext context) {
    if (widget.dataGridConfiguration.isDesktop) {
      // The `showMenu` displays the popup view relative to the topmost of the
      // material app. If using more than one material app in the parent of the
      // data grid, it will be laid out based on the top most material apps'
      // global position. So, it will be displayed in the wrong position. Since
      // the overlay is the parent of every material app widget, we resolved
      // the issue by converting the global to local position of the current
      // overlay and used that new offset to display the show menu.
      final RenderBox renderBox =
          Overlay.of(context).context.findRenderObject()! as RenderBox;
      final Offset newOffset = renderBox.globalToLocal(details.globalPosition);
      final Size viewSize = renderBox.size;
      showMenu(
          surfaceTintColor: Colors.transparent,
          context: context,
          color: widget
              .dataGridConfiguration.dataGridThemeHelper!.filterPopupOuterColor,
          constraints: const BoxConstraints(maxWidth: 274.0),
          position: RelativeRect.fromSize(newOffset & Size.zero, viewSize),
          items: <PopupMenuEntry<String>>[
            _FilterPopupMenuItem<String>(
                column: widget.column,
                dataGridConfiguration: widget.dataGridConfiguration),
          ]).then((_) {
        if (widget.dataGridConfiguration.isDesktop) {
          notifyDataGridPropertyChangeListeners(
              widget.dataGridConfiguration.source,
              propertyName: 'Filtering');
          if (widget.dataGridConfiguration.source.groupedColumns.isNotEmpty) {
            notifyDataGridPropertyChangeListeners(
                widget.dataGridConfiguration.source,
                propertyName: 'grouping');
          }
          widget.dataGridConfiguration.dataGridFilterHelper!
              .isFilterPopupMenuShowing = false;
        }
      });
    } else {
      Navigator.push<_FilterPopup>(
          context,
          MaterialPageRoute<_FilterPopup>(
              builder: (BuildContext context) => _FilterPopup(
                  column: widget.column,
                  dataGridConfiguration: widget.dataGridConfiguration)));
    }
  }

  bool isHovered = false;
  @override
  Widget build(BuildContext context) {
    final bool isFiltered = widget.dataGridConfiguration.source.filterConditions.containsKey(widget.column.columnName);

    bool isSubFiltered = false;

    if (widget.column.getHasSubFilteringFunc != null) {
      isSubFiltered = widget.column.getHasSubFilteringFunc!();
    }

    final Widget filterIcon = isFiltered ?
      _FilteredIcon(
          getFilterIcon: widget.dataGridConfiguration.dataGridThemeHelper!.getFilterIcon,
          isHovered: isHovered,
          isSubFiltered: isSubFiltered,
          iconColor: isHovered
              ? (widget.dataGridConfiguration.dataGridThemeHelper!
              .filterIconHoverColor ??
              widget.dataGridConfiguration.colorScheme!
                  .onSurface[222]!)
              : (widget.dataGridConfiguration.dataGridThemeHelper!
              .filterIconColor ??
              widget.dataGridConfiguration.dataGridThemeHelper!
                  .filterPopupIconColor!),
          filterIcon: widget
              .dataGridConfiguration.dataGridThemeHelper!.filterIcon,
          gridColumnName: widget.column.columnName) :
      _UnfilteredIcon(
          getFilterIcon: widget.dataGridConfiguration.dataGridThemeHelper!.getFilterIcon,
          isHovered: isHovered,
          isSubFiltered: isSubFiltered,
          iconColor: isHovered
              ? (widget.dataGridConfiguration.dataGridThemeHelper!
              .filterIconHoverColor ??
              widget.dataGridConfiguration.colorScheme!
                  .onSurface[222]!)
              : (widget.dataGridConfiguration.dataGridThemeHelper!
              .filterIconColor ??
              widget.dataGridConfiguration.dataGridThemeHelper!
                  .filterPopupIconColor!),
          filterIcon: widget
              .dataGridConfiguration.dataGridThemeHelper!.filterIcon,
          gridColumnName: widget.column.columnName
        );

    return GestureDetector(
      onTapUp: (TapUpDetails details) => onHandleTap(details, context),
      child: Padding(
        padding: widget.column.filterIconPadding,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            setState(() {
              // print('isHovered = true');
              isHovered = true;
            });
          },
          onExit: (_) {
            setState(() {
              // print('isHovered = false');
              isHovered = false;
            });
          },
          child: filterIcon
        ),
      ),
    );
  }
}

class _UnfilteredIcon extends StatelessWidget {
  const _UnfilteredIcon({
    Key? key,
    required this.iconColor,
    required this.filterIcon,
    required this.gridColumnName,
    required this.isSubFiltered,
    required this.isHovered,
    required this.getFilterIcon
  }) : super(key: key);

  final Color iconColor;
  final Widget? filterIcon;
  final String? gridColumnName;
  final bool isSubFiltered;
  final bool isHovered;
  final Function? getFilterIcon;

  @override
  Widget build(BuildContext context) {
    if (getFilterIcon!=null) {
      return getFilterIcon!.call(false, isSubFiltered, isHovered, gridColumnName);
    }

    return filterIcon ??
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Colors.red,
                width: isSubFiltered ? 1 : 0,
                style: (isSubFiltered ? BorderStyle.solid : BorderStyle.none),
              )),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(

                const IconData(0xe702,
                    fontFamily: 'FilterIcon',
                    fontPackage: 'syncfusion_flutter_datagrid'),
                size: 18.0,
                color: iconColor,
                key: ValueKey<String>(
                    'datagrid_filtering_${gridColumnName}_filterIcon'),
              ),
            ],
          ),
        );
  }
}

class _FilteredIcon extends StatelessWidget {
  const _FilteredIcon(
      {Key? key,
      required this.getFilterIcon,
      required this.iconColor,
      required this.filterIcon,
      required this.gridColumnName,
      required this.isHovered,
      required this.isSubFiltered})
      : super(key: key);

  final Color iconColor;
  final Widget? filterIcon;
  final String? gridColumnName;
  final bool isSubFiltered;
  final bool isHovered;
  final Function? getFilterIcon;

  @override
  Widget build(BuildContext context) {
    if (getFilterIcon!=null) {
      return getFilterIcon!.call(true, isSubFiltered, isHovered, gridColumnName);
    }

   return filterIcon ??
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: Colors.red,
              width: isSubFiltered ? 1 : 0,
              style: (isSubFiltered ? BorderStyle.solid : BorderStyle.none),
            )),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              const IconData(0xe704,
                  fontFamily: 'FilterIcon',
                  fontPackage: 'syncfusion_flutter_datagrid'),
              size: 18.0,
              color: iconColor,

              key: ValueKey<String>(
                  'datagrid_filtering_${gridColumnName}_filterIcon'),
            ),
          ],
        ),
      );
  }
}

class _FilterPopupMenuItem<T> extends PopupMenuItem<T> {
  const _FilterPopupMenuItem(
      {required this.column, required this.dataGridConfiguration})
      : super(child: null);

  final GridColumn column;

  final DataGridConfiguration dataGridConfiguration;
  @override
  _FilterPopupMenuItemState<T> createState() => _FilterPopupMenuItemState<T>();
}

class _FilterPopupMenuItemState<T>
    extends PopupMenuItemState<T, _FilterPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    return _FilterPopup(
        column: widget.column,
        dataGridConfiguration: widget.dataGridConfiguration);
  }
}

class _FilterPopup extends StatefulWidget {
  const _FilterPopup(
      {Key? key, required this.column, required this.dataGridConfiguration})
      : super(key: key);

  final GridColumn column;

  final DataGridConfiguration dataGridConfiguration;

  @override
  _FilterPopupState createState() => _FilterPopupState();
}

class _FilterPopupState extends State<_FilterPopup> {
  late bool isMobile;

  late bool isAdvancedFilter;

  // === gabor - 2023.06.07
  late bool isCustomFilter;

  late DataGridFilterHelper filterHelper;

  late DataGridThemeHelper dataGridThemeHelper;
  @override
  void initState() {
    super.initState();
    _initializeFilterProperties();
    filterHelper.isFilterPopupMenuShowing = true;
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: isMobile,
      replacement: Material(
        child: _buildPopupView(),
      ),
      child: Theme(
        data: ThemeData(
            colorScheme: Theme.of(context).colorScheme,
            // Issue: FLUT-869897-The color of the filter pop-up menu was not working properly
            // on the Mobile platform when using the Material 2.
            //
            // Fix: We have to set the useMaterial3 property to the theme data to resolve the above issue.
            useMaterial3: Theme.of(context).useMaterial3),
        child: SafeArea(
          child: Scaffold(
            backgroundColor: dataGridThemeHelper.filterPopupOuterColor,
            appBar: buildAppBar(context),
            resizeToAvoidBottomInset: true,
            body: _buildPopupView(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    filterHelper.isFilterPopupMenuShowing = false;
    super.dispose();
  }

  @override
  void deactivate() {
    filterHelper.isFilterPopupMenuShowing = false;
    super.deactivate();
  }

  void _initializeFilterProperties() {
    isMobile = !widget.dataGridConfiguration.isDesktop;
    filterHelper = widget.dataGridConfiguration.dataGridFilterHelper!;
    dataGridThemeHelper = widget.dataGridConfiguration.dataGridThemeHelper!;
    filterHelper.filterFrom = filterHelper.getFilterForm(widget.column);
    isAdvancedFilter = filterHelper.filterFrom == FilteredFrom.advancedFilter ||
        widget.column.filterPopupMenuOptions?.filterMode ==
            FilterMode.advancedFilterFirst ||
        widget.column.filterPopupMenuOptions?.filterMode ==
            FilterMode.advancedFilter;

    // === gabor - 2023.06.07
    isCustomFilter = widget.column.filterPopupMenuOptions?.filterMode ==
        FilterMode.customFilter;

    filterHelper.checkboxFilterHelper.textController.clear();

    // Need to end edit the current cell to commit the cell value before showing
    // the filtering popup menu.
    filterHelper.endEdit();

    final DataGridAdvancedFilterHelper advancedFilterHelper =
        filterHelper.advancedFilterHelper;
    final List<FilterCondition>? filterConditions = widget.dataGridConfiguration
        .source.filterConditions[widget.column.columnName];

    if (filterConditions == null) {
      filterHelper.setFilterFrom(widget.column, FilteredFrom.none);
    }

    //andras - 2023.8.13
    advancedFilterHelper.neverUseDropDownFilterValues =
        widget.column.filterPopupMenuOptions!.neverUseDropDownFilterValues;

    /// Initializes the data grid source for filtering.
    filterHelper.setDataGridSource(widget.column);

    // Need to initialize the filter values before set the values.
    advancedFilterHelper
      ..setAdvancedFilterType(widget.dataGridConfiguration, widget.column)
      ..generateFilterTypeItems(widget.column);

    /// Initializes the advanced filter properties.
    if (filterConditions != null && isAdvancedFilter) {
      advancedFilterHelper.setAdvancedFilterValues(
          widget.dataGridConfiguration, filterConditions, filterHelper);
    } else {
      advancedFilterHelper
          .resetAdvancedFilterValues(widget.dataGridConfiguration);
    }
  }

  PreferredSize buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52.0),
      child: AppBar(
        elevation: 0.0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
                height: 1.0,
                color: dataGridThemeHelper.filterPopupBorderColor)),
        backgroundColor: dataGridThemeHelper.filterPopupBackgroundColor,
        leading: IconButton(
            key: const ValueKey<String>('datagrid_filtering_cancelFilter_icon'),
            onPressed: closePage,
            icon: Icon(Icons.close,
                size: 22.0, color: dataGridThemeHelper.filterPopupIconColor)),
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
            widget.dataGridConfiguration.localizations
                .sortAndFilterDataGridFilteringLabel,
            style: filterHelper.textStyle),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('datagrid_filtering_applyFilter_icon'),
            onPressed: canDisableOkButton() ? null : onHandleOkButtonTap,
            icon: Icon(Icons.check,
                size: 22.0,
                color: canDisableOkButton()
                    ? widget.dataGridConfiguration.colorScheme!.onSurface
                        .withOpacity(0.38)
                    : filterHelper.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupView() {
    final Color iconColor = dataGridThemeHelper.filterPopupIconColor!;
    final AdvancedFilterType filterType =
        filterHelper.advancedFilterHelper.advancedFilterType;
    final SfLocalizations localizations =
        widget.dataGridConfiguration.localizations;
    final bool isSortAscendingEnabled =
        canEnableSortButton(DataGridSortDirection.ascending);
    final bool isSortDescendingEnabled =
        canEnableSortButton(DataGridSortDirection.descending);
    final bool isClearFilterEnabled = hasFilterConditions();
    const FilterPopupMenuOptions filterPopupMenuOptions =
        FilterPopupMenuOptions();

    // === gabor - 2023.06.07
    bool isCustomFilterMenuEnabled =
        filterPopupMenuOptions.filterMode == FilterMode.customFilter;
    CustomGridFilterBaseWidget customFilterWidget =
        filterPopupMenuOptions.customFilterWidget ??
            CustomGridFilterBaseWidget(
                doFilterRecords: () {}, doClearFilter: () {});

    bool isCheckboxFilterEnabled =
        filterPopupMenuOptions.filterMode == FilterMode.checkboxFilter;
    bool isAdvancedFilterEnabled =
        filterPopupMenuOptions.filterMode == FilterMode.advancedFilter;
    bool isBothFilterEnabled =
        filterPopupMenuOptions.filterMode == FilterMode.both ||
            filterPopupMenuOptions.filterMode == FilterMode.advancedFilterFirst;
    bool canShowSortingOptions = filterPopupMenuOptions.canShowSortingOptions;
    bool canShowClearFilterOption =
        filterPopupMenuOptions.canShowClearFilterOption;
    bool showColumnName = filterPopupMenuOptions.showColumnName;
    double advanceFilterTopPadding = 12;

    if (widget.column.filterPopupMenuOptions != null) {
      isCheckboxFilterEnabled =
          widget.column.filterPopupMenuOptions!.filterMode ==
              FilterMode.checkboxFilter;
      isAdvancedFilterEnabled =
          widget.column.filterPopupMenuOptions!.filterMode ==
              FilterMode.advancedFilter;
      isBothFilterEnabled =
          widget.column.filterPopupMenuOptions!.filterMode == FilterMode.both ||
              widget.column.filterPopupMenuOptions!.filterMode ==
                  FilterMode.advancedFilterFirst;
      canShowSortingOptions =
          widget.column.filterPopupMenuOptions!.canShowSortingOptions;
      canShowClearFilterOption =
          widget.column.filterPopupMenuOptions!.canShowClearFilterOption;
      showColumnName = widget.column.filterPopupMenuOptions!.showColumnName;

      // === gabor - 2023.06.07
      isCustomFilterMenuEnabled =
          widget.column.filterPopupMenuOptions!.filterMode ==
              FilterMode.customFilter;
      customFilterWidget =
          widget.column.filterPopupMenuOptions!.customFilterWidget ??
              CustomGridFilterBaseWidget(
                  doFilterRecords: () {}, doClearFilter: () {});
    }
    Widget buildPopup({Size? viewSize}) {
      return SingleChildScrollView(
        key: const ValueKey<String>('datagrid_filtering_scrollView'),
        child: Container(
          width: isMobile ? null : 274.0,
          color: dataGridThemeHelper.filterPopupBackgroundColor,
          child: Column(
            children: <Widget>[
              if (canShowSortingOptions)
                _FilterPopupMenuTile(
                    style: isSortAscendingEnabled
                        ? filterHelper.textStyle
                        : filterHelper.disableTextStyle,
                    height: filterHelper.tileHeight,
                    prefix: Icon(
                      const IconData(0xe700,
                          fontFamily: 'FilterIcon',
                          fontPackage: 'syncfusion_flutter_datagrid'),
                      // fontPackage: 'trendi_view_generator'),
                      color: isSortAscendingEnabled
                          ? iconColor
                          : dataGridThemeHelper.filterPopupDisableIconColor,
                      size: filterHelper.textStyle.fontSize! + 10,
                    ),
                    prefixPadding: EdgeInsets.only(
                        left: 4.0,
                        right: filterHelper.textStyle.fontSize!,
                        bottom: filterHelper.textStyle.fontSize! > 14
                            ? filterHelper.textStyle.fontSize! - 14
                            : 0),
                    onTap: isSortAscendingEnabled
                        ? onHandleSortAscendingTap
                        : null,
                    child: Text(
                        grid_helper.getSortButtonText(
                            localizations, true, filterType),
                        overflow: TextOverflow.ellipsis)),
              if (canShowSortingOptions)
                _FilterPopupMenuTile(
                  style: isSortDescendingEnabled
                      ? filterHelper.textStyle
                      : filterHelper.disableTextStyle,
                  height: filterHelper.tileHeight,
                  prefix: Icon(
                    const IconData(0xe701,
                        fontFamily: 'FilterIcon',
                        fontPackage: 'syncfusion_flutter_datagrid'),
                    // fontPackage: 'trendi_view_generator'),
                    color: isSortDescendingEnabled
                        ? iconColor
                        : dataGridThemeHelper.filterPopupDisableIconColor,
                    size: filterHelper.textStyle.fontSize! + 10,
                  ),
                  prefixPadding: EdgeInsets.only(
                      left: 4.0,
                      right: filterHelper.textStyle.fontSize!,
                      bottom: filterHelper.textStyle.fontSize! > 14
                          ? filterHelper.textStyle.fontSize! - 14
                          : 0),
                  onTap: isSortDescendingEnabled
                      ? onHandleSortDescendingTap
                      : null,
                  child: Text(
                    grid_helper.getSortButtonText(
                      localizations,
                      false,
                      filterType,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (canShowSortingOptions)
                const Divider(indent: 8.0, endIndent: 8.0),
              if (canShowClearFilterOption)
                _FilterPopupMenuTile(
                  style: isClearFilterEnabled
                      ? filterHelper.textStyle
                      : filterHelper.disableTextStyle,
                  height: filterHelper.tileHeight,
                  prefix: Icon(
                      const IconData(0xe703,
                          fontFamily: 'FilterIcon',
                          fontPackage: 'syncfusion_flutter_datagrid'),
                      // fontPackage: 'trendi_view_generator'),
                      size: filterHelper.textStyle.fontSize! + 8,
                      color: isClearFilterEnabled
                          ? iconColor
                          : dataGridThemeHelper.filterPopupDisableIconColor),
                  prefixPadding: EdgeInsets.only(
                      left: 4.0,
                      right: filterHelper.textStyle.fontSize!,
                      bottom: filterHelper.textStyle.fontSize! > 14
                          ? filterHelper.textStyle.fontSize! - 14
                          : 0),
                  onTap: isClearFilterEnabled ? onHandleClearFilterTap : null,
                  child: Text(getClearFilterText(localizations, showColumnName),
                      overflow: TextOverflow.ellipsis),
                ),
              if (isAdvancedFilterEnabled)
                _AdvancedFilterPopupMenu(
                  setState: setState,
                  dataGridConfiguration: widget.dataGridConfiguration,
                  advanceFilterTopPadding: advanceFilterTopPadding,
                ),
              if (isBothFilterEnabled)
                _FilterPopupMenuTile(
                  style: filterHelper.textStyle,
                  height: filterHelper.tileHeight,
                  onTap: onHandleExpansionTileTap,
                  prefix: Icon(
                      filterHelper.getFilterForm(widget.column) ==
                              FilteredFrom.advancedFilter
                          ? const IconData(0xe704,
                              fontFamily: 'FilterIcon',
                              fontPackage: 'syncfusion_flutter_datagrid')
                          // fontPackage: 'trendi_view_generator'),
                          : const IconData(0xe702,
                              fontFamily: 'FilterIcon',
                              fontPackage: 'syncfusion_flutter_datagrid'),
                      size: filterHelper.textStyle.fontSize! + 6,
                      color: iconColor),
                  suffix: Icon(
                      isAdvancedFilter
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: filterHelper.textStyle.fontSize! + 6,
                      color: iconColor),
                  prefixPadding: EdgeInsets.only(
                      left: 4.0,
                      right: filterHelper.textStyle.fontSize!,
                      bottom: filterHelper.textStyle.fontSize! > 14
                          ? filterHelper.textStyle.fontSize! - 14
                          : 0),
                  child: Text(
                    grid_helper.getFilterTileText(localizations, filterType),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // === gabor - 2023.06.07
              if (isCustomFilterMenuEnabled)
                _FilterPopupMenuTile(
                  //style: isClearFilterEnabled ? filterHelper.textStyle : filterHelper.disableTextStyle,
                  style: filterHelper.textStyle,
                  // height: filterHelper.tileHeight,
                  prefix: Icon(Icons.filter_alt,
                      size: filterHelper.textStyle.fontSize! + 8,
                      color: isClearFilterEnabled
                          ? iconColor
                          : dataGridThemeHelper.filterPopupDisableIconColor),
                  prefixPadding: EdgeInsets.only(
                      left: 4.0,
                      right: filterHelper.textStyle.fontSize!,
                      bottom: filterHelper.textStyle.fontSize! > 14
                          ? filterHelper.textStyle.fontSize! - 14
                          : 0),
                  onTap: null,
                  child: customFilterWidget,
                ),

              if (isCheckboxFilterEnabled || isBothFilterEnabled)
                Visibility(
                  visible: isAdvancedFilter,
                  replacement: _CheckboxFilterMenu(
                    column: widget.column,
                    setState: setState,
                    viewSize: viewSize,
                    dataGridConfiguration: widget.dataGridConfiguration,
                  ),
                  child: _AdvancedFilterPopupMenu(
                    setState: setState,
                    dataGridConfiguration: widget.dataGridConfiguration,
                    advanceFilterTopPadding: advanceFilterTopPadding,
                  ),
                ),
              if (!isMobile) const Divider(height: 10),
              if (!isMobile)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      SizedBox(
                        width: 120.0,
                        height: filterHelper.tileHeight - 8,
                        child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor:
                                  MaterialStateProperty.resolveWith<Color?>(
                                (Set<MaterialState> states) {
                                  // Issue:
                                  // FLUT-7487-The buttons UX in the filter popup menu is not very intuitive when using Material 3 design.
                                  //
                                  // Fix:
                                  // There is an issue with the button user experience (UX) in the filter popup menu,
                                  // which is caused by the default background color of the "ElevatedButton" widget
                                  // being set to the surface color in the Material 3 design. To address this issue,
                                  // we set the background color of the button to the primary color if it is not disabled.
                                  // This means that the default value is ignored, and the given color is used instead.
                                  if (states.contains(MaterialState.disabled)) {
                                    return null;
                                  } else {
                                    return filterHelper.primaryColor;
                                  }
                                },
                              ),
                            ),
                            onPressed: canDisableOkButton()
                                ? null
                                : onHandleOkButtonTap,
                            child: Text(localizations.okDataGridFilteringLabel,
                                style: TextStyle(
                                    color: const Color(0xFFFFFFFF),
                                    fontSize: filterHelper.textStyle.fontSize,
                                    fontFamily:
                                        filterHelper.textStyle.fontFamily))),
                      ),
                      SizedBox(
                        width: 120.0,
                        height: filterHelper.tileHeight - 8,
                        child: OutlinedButton(
                            onPressed: closePage,
                            child: Text(
                              localizations.cancelDataGridFilteringLabel,
                              style: TextStyle(
                                  color: filterHelper.primaryColor,
                                  fontSize: filterHelper.textStyle.fontSize,
                                  fontFamily:
                                      filterHelper.textStyle.fontFamily),
                            )),
                      ),
                    ],
                  ),
                )
            ],
          ),
        ),
      );
    }

    if (isAdvancedFilterEnabled) {
      isAdvancedFilter = true;
    }
    if (isAdvancedFilterEnabled &&
        !canShowClearFilterOption &&
        !canShowSortingOptions) {
      advanceFilterTopPadding = 6;
    }

    if (isMobile) {
      return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              buildPopup(viewSize: constraints.biggest));
    } else {
      return buildPopup();
    }
  }

  void onHandleSortAscendingTap() {
    if (widget.dataGridConfiguration.allowSorting) {
      filterHelper.onSortButtonClick(
          widget.column, DataGridSortDirection.ascending);
    }
    Navigator.pop(context);
  }

  void onHandleSortDescendingTap() {
    if (widget.dataGridConfiguration.allowSorting) {
      filterHelper.onSortButtonClick(
          widget.column, DataGridSortDirection.descending);
    }
    Navigator.pop(context);
  }

  void onHandleClearFilterTap() {
    if (isCustomFilter) {
      widget.column.filterPopupMenuOptions?.customFilterWidget?.doClearFilter();
    } else {
      filterHelper.onClearFilterButtonClick(widget.column);
    }
    Navigator.pop(context);
  }

  void onHandleExpansionTileTap() {
    setState(() {
      isAdvancedFilter = !isAdvancedFilter;
    });
  }

  void onHandleOkButtonTap() {
    // === gabor - 2023.06.07 - begin
    if (isCustomFilter) {
      widget.column.filterPopupMenuOptions?.customFilterWidget
          ?.doFilterRecords();
    } else {
      // === gabor - 2023.06.07 - end
      filterHelper.createFilterConditions(!isAdvancedFilter, widget.column);
    }
    Navigator.pop(context);
  }

  void closePage() {
    Navigator.pop(context);
  }

  bool hasFilterConditions() {
    return widget.dataGridConfiguration.source.filterConditions
        .containsKey(widget.column.columnName);
  }

  bool canDisableOkButton() {
    // === gabor - 2023.06.07 - begin
    if (isCustomFilter) {
      return false;
    }
    // === gabor - 2023.06.07 - end

    if (isAdvancedFilter) {
      final DataGridAdvancedFilterHelper helper =
          filterHelper.advancedFilterHelper;
      return (helper.filterValue1 == null && helper.filterValue2 == null) &&
          !helper.disableFilterTypes.contains(helper.filterType1) &&
          !helper.disableFilterTypes.contains(helper.filterType2);
    } else {
      final bool? isSelectAllChecked =
          filterHelper.checkboxFilterHelper.isSelectAllChecked;
      return (isSelectAllChecked != null && !isSelectAllChecked) ||
          filterHelper.checkboxFilterHelper.items.isEmpty;
    }
  }

  bool canEnableSortButton(DataGridSortDirection sortDirection) {
    final DataGridConfiguration configuration = widget.dataGridConfiguration;
    if (configuration.allowSorting && widget.column.allowSorting) {
      return configuration.source.sortedColumns.isEmpty ||
          !configuration.source.sortedColumns.any((SortColumnDetails column) =>
              column.name == widget.column.columnName &&
              column.sortDirection == sortDirection);
    }
    return false;
  }

  String getClearFilterText(SfLocalizations localization, bool showColumnName) {
    if (showColumnName) {
      return '${localization.clearFilterDataGridFilteringLabel} ${localization.fromDataGridFilteringLabel} "${widget.column.columnName}"';
    } else {
      return localization.clearFilterDataGridFilteringLabel;
    }
  }
}

class _FilterPopupMenuTile extends StatelessWidget {
  const _FilterPopupMenuTile(
      {Key? key,
      required this.child,
      this.onTap,
      this.prefix,
      this.suffix,
      this.height,
      required this.style,
      this.prefixPadding = EdgeInsets.zero})
      : super(key: key);

  final Widget child;

  final Widget? prefix;

  final Widget? suffix;

  final double? height;

  final TextStyle style;

  final VoidCallback? onTap;

  final EdgeInsets prefixPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: MaterialButton(
        onPressed: onTap,
        child: Row(
          children: <Widget>[
            Padding(
              padding: prefixPadding,
              child: SizedBox(
                width: 24.0,
                height: 24.0,
                child: prefix,
              ),
            ),
            Expanded(
              child: DefaultTextStyle(style: style, child: child),
            ),
            if (suffix != null) SizedBox(width: 40.0, child: suffix)
          ],
        ),
      ),
    );
  }
}

class _FilterMenuDropdown extends StatelessWidget {
  const _FilterMenuDropdown(
      {required this.child,
      required this.padding,
      required this.height,
      this.suffix,
      Key? key})
      : super(key: key);

  final Widget child;

  final Widget? suffix;

  final double height;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: height,
        child: Row(
          children: <Widget>[
            Expanded(
              child: child,
            ),
            if (suffix != null)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: suffix,
              )
          ],
        ),
      ),
    );
  }
}

class _CheckboxFilterMenu extends StatelessWidget {
  _CheckboxFilterMenu(
      {Key? key,
      required this.setState,
      required this.column,
      required this.viewSize,
      required this.dataGridConfiguration})
      : super(key: key);

  final StateSetter setState;

  final DataGridConfiguration dataGridConfiguration;

  final GridColumn column;

  final Size? viewSize;

  final FocusNode checkboxFocusNode = FocusNode(skipTraversal: true);

  bool get isMobile {
    return !dataGridConfiguration.isDesktop;
  }

  DataGridCheckboxFilterHelper get filterHelper {
    return dataGridConfiguration.dataGridFilterHelper!.checkboxFilterHelper;
  }

  @override
  Widget build(BuildContext context) {
    final Color onSurface = dataGridConfiguration.colorScheme!.onSurface;

    return Column(
      children: <Widget>[
        _buildSearchBox(onSurface, context),
        _buildCheckboxListView(context),
      ],
    );
  }

  Widget _buildCheckboxListView(BuildContext context) {
    final DataGridFilterHelper helper =
        dataGridConfiguration.dataGridFilterHelper!;

    // 340.0 it's a occupied height in the current view by the other widgets.
    double occupiedHeight = 340.0;

    // Need to set the Checkbox Filter height in the mobile platform
    // based on the options enabled in the Filter popup menu
    if (column.filterPopupMenuOptions != null && isMobile) {
      if (!column.filterPopupMenuOptions!.canShowSortingOptions) {
        // 16.0 is the height of the divider shown below the sorting options
        occupiedHeight -= (helper.tileHeight * 2) + 16.0;
      }
      if (!column.filterPopupMenuOptions!.canShowClearFilterOption) {
        occupiedHeight -= helper.tileHeight;
      }
      if (column.filterPopupMenuOptions!.filterMode ==
          FilterMode.checkboxFilter) {
        occupiedHeight -= helper.tileHeight;
      }
    }

    // Gets the remaining height of the current view to fill the checkbox
    // listview in the mobile platform.
    final double checkboxHeight =
        isMobile ? max(viewSize!.height - occupiedHeight, 120.0) : 200.0;
    final double selectAllButtonHeight =
        isMobile ? helper.tileHeight - 4 : helper.tileHeight;

    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Visibility(
        visible: filterHelper.items.isNotEmpty,
        replacement: SizedBox(
          height: checkboxHeight + selectAllButtonHeight,
          child: Center(
              child: Text(dataGridConfiguration
                  .localizations.noMatchesDataGridFilteringLabel)),
        ),
        child: CheckboxTheme(
          data: CheckboxThemeData(
            side: BorderSide(
                width: 2.0,
                color: dataGridConfiguration.colorScheme!.onSurface
                    .withOpacity(0.6)),

            // Issue: The checkbox fill color is applied even when the checkbox is not selected.
            // The framework changed this behavior in Flutter 3.13.0 onwards.
            // Refer to the issue: https://github.com/flutter/flutter/issues/130295
            // Guide: https://github.com/flutter/website/commit/224bdc9cc3e8dfb8af94d76f275824cdcf76ba4d
            // Fix: As per the framework guide, we have to set the fillColor property to transparent
            // when the checkbox is not selected.
            fillColor:
                MaterialStateProperty.resolveWith((Set<MaterialState> states) {
              if (!states.contains(MaterialState.selected)) {
                return Colors.transparent;
              }
              return helper.primaryColor;
            }),
          ),
          child: Column(children: <Widget>[
            _FilterPopupMenuTile(
              style: helper.textStyle,
              height: selectAllButtonHeight,
              prefixPadding: const EdgeInsets.only(left: 4.0, right: 10.0),
              prefix: Checkbox(
                focusNode: checkboxFocusNode,
                tristate: filterHelper.isSelectAllInTriState,
                value: filterHelper.isSelectAllChecked,
                onChanged: (_) => onHandleSelectAllCheckboxTap(),
              ),
              onTap: onHandleSelectAllCheckboxTap,
              child: Text(
                dataGridConfiguration
                    .localizations.selectAllDataGridFilteringLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              height: checkboxHeight,
              child: ListView.builder(
                  key: const ValueKey<String>(
                      'datagrid_filtering_checkbox_listView'),
                  prototypeItem: buildCheckboxTile(
                      filterHelper.items.length - 1, helper.textStyle),
                  itemCount: filterHelper.items.length,
                  itemBuilder: (BuildContext context, int index) =>
                      buildCheckboxTile(index, helper.textStyle)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSearchBox(Color onSurface, BuildContext context) {
    final DataGridFilterHelper helper =
        dataGridConfiguration.dataGridFilterHelper!;
    final DataGridThemeHelper dataGridThemeHelper =
        dataGridConfiguration.dataGridThemeHelper!;

    void onSearchboxSubmitted(String value) {
      if (filterHelper.items.isNotEmpty) {
        helper.createFilterConditions(true, column);
        Navigator.pop(context);
      } else {
        filterHelper.searchboxFocusNode.requestFocus();
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: SizedBox(
        height: isMobile ? helper.tileHeight : helper.tileHeight - 4,
        child: TextField(
          style: helper.textStyle,
          key: const ValueKey<String>('datagrid_filtering_search_textfield'),
          focusNode: filterHelper.searchboxFocusNode,
          controller: filterHelper.textController,
          onChanged: onHandleSearchTextFieldChanged,
          onSubmitted: onSearchboxSubmitted,
          decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: dataGridThemeHelper.filterPopupBorderColor!)),
              suffixIcon: Visibility(
                  visible: filterHelper.textController.text.isEmpty,
                  replacement: IconButton(
                      key: const ValueKey<String>(
                          'datagrid_filtering_clearSearch_icon'),
                      iconSize: helper.textStyle.fontSize! + 8,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: 22.0, height: 22.0),
                      onPressed: () {
                        filterHelper.textController.clear();
                        onHandleSearchTextFieldChanged('');
                      },
                      icon: Icon(Icons.close,
                          color: dataGridThemeHelper.filterPopupIconColor)),
                  child: Icon(Icons.search,
                      size: helper.textStyle.fontSize! + 8,
                      color: dataGridThemeHelper.filterPopupIconColor)),
              contentPadding: isMobile
                  ? const EdgeInsets.all(16.0)
                  : const EdgeInsets.all(8.0),
              border: const OutlineInputBorder(),
              hintStyle: helper.textStyle,
              hintText: dataGridConfiguration
                  .localizations.searchDataGridFilteringLabel),
        ),
      ),
    );
  }

  Widget? buildCheckboxTile(int index, TextStyle style) {
    if (filterHelper.items.isNotEmpty) {
      final FilterElement element = filterHelper.items[index];
      final String displayText = dataGridConfiguration.dataGridFilterHelper!
          .getDisplayValue(element.value);
      return _FilterPopupMenuTile(
          style: style,
          height: isMobile ? style.fontSize! + 34 : style.fontSize! + 26,
          prefixPadding: const EdgeInsets.only(left: 4.0, right: 10.0),
          prefix: Checkbox(
              focusNode: checkboxFocusNode,
              value: element.isSelected,
              onChanged: (_) => onHandleCheckboxTap(element)),
          onTap: () => onHandleCheckboxTap(element),
          child: Text(displayText, overflow: TextOverflow.ellipsis));
    }
    return null;
  }

  void onHandleCheckboxTap(FilterElement element) {
    element.isSelected = !element.isSelected;
    filterHelper.ensureSelectAllCheckboxState();
    setState(() {});
  }

  void onHandleSelectAllCheckboxTap() {
    final bool useSelected = filterHelper.isSelectAllInTriState ||
        (filterHelper.isSelectAllChecked != null &&
            filterHelper.isSelectAllChecked!);
    for (final FilterElement item in filterHelper.filterCheckboxItems) {
      item.isSelected = !useSelected;
    }

    filterHelper.ensureSelectAllCheckboxState();
    setState(() {});
  }

  void onHandleSearchTextFieldChanged(String value) {
    filterHelper.onSearchTextFieldTextChanged(value);
    setState(() {});
  }
}

class _AdvancedFilterPopupMenu extends StatelessWidget {
  const _AdvancedFilterPopupMenu(
      {Key? key,
      required this.setState,
      required this.dataGridConfiguration,
      required this.advanceFilterTopPadding})
      : super(key: key);

  final StateSetter setState;

  final DataGridConfiguration dataGridConfiguration;

  final double advanceFilterTopPadding;

  bool get isMobile {
    return !dataGridConfiguration.isDesktop;
  }

  DataGridAdvancedFilterHelper get filterHelper {
    return dataGridConfiguration.dataGridFilterHelper!.advancedFilterHelper;
  }

  @override
  Widget build(BuildContext context) {
    final DataGridFilterHelper helper =
        dataGridConfiguration.dataGridFilterHelper!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: <Widget>[
          _FilterMenuDropdown(
            height: helper.textStyle.fontSize! + 2,
            padding: EdgeInsets.only(top: advanceFilterTopPadding, bottom: 8.0),
            child: Text(
              '${dataGridConfiguration.localizations.showRowsWhereDataGridFilteringLabel}:',
              style: TextStyle(
                  fontFamily: helper.textStyle.fontFamily,
                  fontSize: helper.textStyle.fontSize,
                  color: helper.textStyle.color,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _FilterMenuDropdown(
            height: isMobile ? helper.tileHeight + 4 : helper.tileHeight - 4,
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildFilterTypeDropdown(isFirstButton: true),
          ),
          _FilterMenuDropdown(
            height: isMobile ? helper.tileHeight + 4 : helper.tileHeight - 4,
            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
            suffix: _getTrailingWidget(context, true),
            child: _buildFilterValueDropdown(isTopButton: true),
          ),
          _buildRadioButtons(),
          _FilterMenuDropdown(
            height: isMobile ? helper.tileHeight + 4 : helper.tileHeight - 4,
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: _buildFilterTypeDropdown(isFirstButton: false),
          ),
          _FilterMenuDropdown(
            height: isMobile ? helper.tileHeight + 4 : helper.tileHeight - 4,
            padding: const EdgeInsets.only(bottom: 8.0),
            suffix: _getTrailingWidget(context, false),
            child: _buildFilterValueDropdown(isTopButton: false),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioButtons() {
    final DataGridFilterHelper helper =
        dataGridConfiguration.dataGridFilterHelper!;
    final SfLocalizations localizations = dataGridConfiguration.localizations;

    void handleChanged(bool? value) {
      setState(() {
        filterHelper.isOrPredicate = !filterHelper.isOrPredicate;
      });
    }

    return Row(
      children: <Widget>[
        Row(children: <Widget>[
          SizedBox.fromSize(
            size: const Size(24.0, 24.0),
            child: Radio<bool>(
                key: const ValueKey<String>('datagrid_filtering_and_button'),
                value: false,
                activeColor: helper.primaryColor,
                onChanged: handleChanged,
                groupValue: filterHelper.isOrPredicate),
          ),
          const SizedBox(width: 8.0),
          Text(
            localizations.andDataGridFilteringLabel,
            style: helper.textStyle,
          ),
        ]),
        const SizedBox(width: 16.0),
        Row(children: <Widget>[
          SizedBox.fromSize(
            size: const Size(24.0, 24.0),
            child: Radio<bool>(
                key: const ValueKey<String>('datagrid_filtering_or_button'),
                value: true,
                activeColor: helper.primaryColor,
                onChanged: handleChanged,
                groupValue: filterHelper.isOrPredicate),
          ),
          const SizedBox(width: 8.0),
          Text(
            localizations.orDataGridFilteringLabel,
            style: helper.textStyle,
          ),
        ]),
      ],
    );
  }

  Widget _buildFilterValueDropdown({required bool isTopButton}) {
    final DataGridFilterHelper helper =
        dataGridConfiguration.dataGridFilterHelper!;

    final DataGridThemeHelper dataGridThemeHelper =
        dataGridConfiguration.dataGridThemeHelper!;

    void setValue(Object? value) {
      if (isTopButton) {
        filterHelper.filterValue1 = value;
      } else {
        filterHelper.filterValue2 = value;
      }
      setState(() {});
    }

    TextInputType getTextInputType() {
      if (filterHelper.advancedFilterType == AdvancedFilterType.text) {
        return TextInputType.text;
      }
      return TextInputType.number;
    }

    List<TextInputFormatter>? getInputFormatters() {
      if (filterHelper.advancedFilterType == AdvancedFilterType.date) {
        return <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        ];
      } else if (filterHelper.advancedFilterType ==
          AdvancedFilterType.numeric) {
        return <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ];
      }
      return null;
    }

    Widget buildDropdownFormField() {
      return DropdownButtonHideUnderline(
        child: DropdownButtonFormField<Object>(
          dropdownColor: dataGridThemeHelper.filterPopupOuterColor,
          key: isTopButton
              ? const ValueKey<String>(
                  'datagrid_filtering_filterValue_first_button')
              : const ValueKey<String>(
                  'datagrid_filtering_filterValue_second_button'),
          decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: dataGridThemeHelper.filterPopupBorderColor!),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              border: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: dataGridThemeHelper.filterPopupBorderColor!))),
          icon: Icon(Icons.keyboard_arrow_down,
              size: helper.textStyle.fontSize! + 8,
              color: dataGridThemeHelper.filterPopupIconColor),
          isExpanded: true,
          value: isTopButton
              ? filterHelper.filterValue1
              : filterHelper.filterValue2,
          style: helper.textStyle,
          items: filterHelper.items
              .map<DropdownMenuItem<Object>>((FilterElement value) =>
                  DropdownMenuItem<Object>(
                      value: value.value,
                      child: Text(helper.getDisplayValue(value.value))))
              .toList(),
          onChanged: enableDropdownButton(isTopButton) ? setValue : null,
        ),
      );
    }

    Widget buildTextField() {
      return TextField(
        style: helper.textStyle,
        key: isTopButton
            ? const ValueKey<String>(
                'datagrid_filtering_filterValue_first_button')
            : const ValueKey<String>(
                'datagrid_filtering_filterValue_second_button'),
        controller: isTopButton
            ? filterHelper.firstValueTextController
            : filterHelper.secondValueTextController,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        keyboardType: getTextInputType(),
        inputFormatters: getInputFormatters(),
        onChanged: (String? value) {
          value = value != null && value.isEmpty ? null : value;
          setValue(helper.getActualValue(value));
        },
        decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: dataGridThemeHelper.filterPopupBorderColor!)),
            contentPadding: isMobile
                ? const EdgeInsets.all(16.0)
                : const EdgeInsets.all(8.0),
            border: const OutlineInputBorder(),
            hintStyle: const TextStyle(fontSize: 14.0)),
      );
    }

    return (filterHelper.neverUseDropDownFilterValues ||
            canBuildTextField(isTopButton))
        ? buildTextField()
        : buildDropdownFormField();
  }

  Widget _buildFilterTypeDropdown({required bool isFirstButton}) {
    final DataGridFilterHelper helper =
        dataGridConfiguration.dataGridFilterHelper!;

    final DataGridThemeHelper dataGridThemeHelper =
        dataGridConfiguration.dataGridThemeHelper!;

    void handleChanged(String? value) {
      if (isFirstButton) {
        filterHelper.filterType1 = value;
      } else {
        filterHelper.filterType2 = value;
      }

      // Need to set the filter values to null if the type is null or empty.
      if (filterHelper.disableFilterTypes.contains(value)) {
        if (isFirstButton) {
          filterHelper.filterValue1 = null;
        } else {
          filterHelper.filterValue2 = null;
        }
      }

      // Need to set the current filter value to the controller's text to retains
      // the same value in the text field itself.
      if (filterHelper.textFieldFilterTypes.contains(value)) {
        if (isFirstButton) {
          filterHelper.firstValueTextController.text =
              helper.getDisplayValue(filterHelper.filterValue1);
        } else {
          filterHelper.secondValueTextController.text =
              helper.getDisplayValue(filterHelper.filterValue2);
        }
      } else {
        // Need to set the filter values to null if that value doesn't exist in
        // the data source when the filter type switching from the text field to
        // dropdown.
        bool isInValidText(Object? filterValue) => !filterHelper.items
            .any((FilterElement element) => element.value == filterValue);
        if (isFirstButton) {
          if (isInValidText(filterHelper.filterValue1)) {
            filterHelper.filterValue1 = null;
          }
        } else {
          if (isInValidText(filterHelper.filterValue2)) {
            filterHelper.filterValue2 = null;
          }
        }
      }
      setState(() {});
    }

    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        dropdownColor: dataGridThemeHelper.filterPopupOuterColor,
        key: isFirstButton
            ? const ValueKey<String>(
                'datagrid_filtering_filterType_first_button')
            : const ValueKey<String>(
                'datagrid_filtering_filterType_second_button'),
        decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: dataGridThemeHelper.filterPopupBorderColor!)),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            border: OutlineInputBorder(
                borderSide: BorderSide(
                    color: dataGridThemeHelper.filterPopupBorderColor!))),
        icon: Icon(Icons.keyboard_arrow_down,
            size: helper.textStyle.fontSize! + 8,
            color: dataGridThemeHelper.filterPopupIconColor),
        isExpanded: true,
        value:
            isFirstButton ? filterHelper.filterType1 : filterHelper.filterType2,
        style: helper.textStyle,
        items: filterHelper.filterTypeItems
            .map<DropdownMenuItem<String>>((String value) =>
                DropdownMenuItem<String>(value: value, child: Text(value)))
            .toList(),
        onChanged: handleChanged,
      ),
    );
  }

  Widget? _getTrailingWidget(BuildContext context, bool isFirstButton) {
    final DataGridFilterHelper helper =
        dataGridConfiguration.dataGridFilterHelper!;
    final DataGridThemeHelper dataGridThemeHelper =
        dataGridConfiguration.dataGridThemeHelper!;

    if (filterHelper.advancedFilterType == AdvancedFilterType.numeric) {
      return null;
    }

    Future<void> handleDatePickerTap() async {
      final DateTime currentDate = DateTime.now();
      final DateTime firstDate = (filterHelper.items.length > 0) ? filterHelper.items.first.value as DateTime : DateTime.parse('1900-01-01 00:00:00.000');
      final DateTime lastDate = (filterHelper.items.length > 1) ? filterHelper.items.last.value as DateTime :  DateTime.parse('2100-01-01 00:00:00.000');

      DateTime initialDate = firstDate;

      if ((currentDate.isAfter(firstDate) && currentDate.isBefore(lastDate)) ||
          (lastDate.day == currentDate.day &&
           lastDate.month == currentDate.month &&
           lastDate.year == currentDate.year)) {
        initialDate = currentDate;
      }
      DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        helpText: 'Select a date',
      );

      // Need to return if user presses the cancel button to close the data picker view.
      if (selectedDate == null) {
        return;
      }

      if (filterHelper.neverUseDropDownFilterValues) {
        //
      } else {
        final bool isVaildDate = filterHelper.items
            .any((FilterElement element) => element.value == selectedDate);
        final String? filterType =
            isFirstButton ? filterHelper.filterType1 : filterHelper.filterType2;
        final bool isValidType = filterType != null &&
            filterHelper.textFieldFilterTypes.contains(filterType);
        selectedDate = isVaildDate || isValidType ? selectedDate : null;
      }

      setState(() {
        final String newValue = helper.getDisplayValue(selectedDate);
        if (isFirstButton) {
          filterHelper.filterValue1 = selectedDate;
          filterHelper.firstValueTextController.text = newValue;
        } else {
          filterHelper.filterValue2 = selectedDate;
          filterHelper.secondValueTextController.text = newValue;
        }
      });
    }

    void handleCaseSensitiveTap() {
      setState(() {
        if (isFirstButton) {
          filterHelper.isCaseSensitive1 = !filterHelper.isCaseSensitive1;
        } else {
          filterHelper.isCaseSensitive2 = !filterHelper.isCaseSensitive2;
        }
      });
    }

    Color getColor() {
      final bool isSelected = isFirstButton
          ? filterHelper.isCaseSensitive1
          : filterHelper.isCaseSensitive2;
      return isSelected
          ? helper.primaryColor
          : dataGridThemeHelper.filterPopupIconColor!;
    }

    bool canEnableButton() {
      final String? value =
          isFirstButton ? filterHelper.filterType1 : filterHelper.filterType2;
      return value != null && !filterHelper.disableFilterTypes.contains(value);
    }

    if (filterHelper.advancedFilterType == AdvancedFilterType.text) {
      const IconData caseSensitiveIcon = IconData(0xe705,
          fontFamily: 'FilterIcon', fontPackage: 'syncfusion_flutter_datagrid');
      // const IconData caseSensitiveIcon = IconData(0xe705, fontFamily: 'FilterIcon', fontPackage: 'trendi_view_generator');

      return IconButton(
          key: isFirstButton
              ? const ValueKey<String>(
                  'datagrid_filtering_case_sensitive_first_button')
              : const ValueKey<String>(
                  'datagrid_filtering_case_sensitive_second_button'),
          iconSize: 22.0,
          splashRadius: 20.0,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 22.0, height: 22.0),
          onPressed: canEnableButton() ? handleCaseSensitiveTap : null,
          icon: Icon(caseSensitiveIcon, size: 22.0, color: getColor()));
    } else {
      return IconButton(
          key: isFirstButton
              ? const ValueKey<String>(
                  'datagrid_filtering_date_picker_first_button')
              : const ValueKey<String>(
                  'datagrid_filtering_date_picker_second_button'),
          iconSize: 22.0,
          splashRadius: 20.0,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 22.0, height: 22.0),
          onPressed: canEnableButton() ? handleDatePickerTap : null,
          icon: Icon(Icons.calendar_today_outlined,
              size: 22.0,
              color: dataGridConfiguration.colorScheme!.onSurface
                  .withOpacity(0.6)));
    }
  }

  bool enableDropdownButton(bool isTopButton) {
    return !filterHelper.disableFilterTypes.contains(
        isTopButton ? filterHelper.filterType1 : filterHelper.filterType2);
  }

  bool canBuildTextField(bool isTopButton) {
    final String filterType =
        isTopButton ? filterHelper.filterType1! : filterHelper.filterType2!;
    if (filterHelper.textFieldFilterTypes.contains(filterType)) {
      return true;
    }
    return false;
  }
}

BorderDirectional _getCellBorder(
    DataGridConfiguration dataGridConfiguration, DataCellBase dataCell) {
  final int rowIndex = (dataCell.rowSpan > 0)
      ? dataCell.rowIndex - dataCell.rowSpan
      : dataCell.rowIndex;
  final bool isSelected = (rowIndex > 0) && isSelectedRow(dataGridConfiguration, dataGridConfiguration.source.rows[rowIndex-1]);

  final double borderWidth =
    isSelected ?
    (dataGridConfiguration.dataGridThemeHelper!.gridSelectedRowLineStrokeWidth ?? dataGridConfiguration.dataGridThemeHelper!.gridLineStrokeWidth!) :
    dataGridConfiguration.dataGridThemeHelper!.gridLineStrokeWidth!;
  final Color borderColor =
    isSelected ?
    (dataGridConfiguration.dataGridThemeHelper!.gridSelectedRowLineColor ?? dataGridConfiguration.dataGridThemeHelper!.gridLineColor!) :
    dataGridConfiguration.dataGridThemeHelper!.gridLineColor!;

  final int columnIndex = dataCell.columnIndex;
  final bool isStackedHeaderCell =
      dataCell.cellType == CellType.stackedHeaderCell;
  final bool isHeaderCell = dataCell.cellType == CellType.headerCell;
  final bool isTableSummaryCell =
      dataCell.cellType == CellType.tableSummaryCell;
  final bool isRowCell = dataCell.cellType == CellType.gridCell;
  final bool isCheckboxCell = dataCell.cellType == CellType.checkboxCell;
  final bool isIndentCell = dataCell.cellType == CellType.indentCell;
  final bool isCaptionSummaryCell =
      dataCell.cellType == CellType.captionSummaryCell;
  final bool isStackedHeaderRow =
      dataCell.dataRow!.rowType == RowType.stackedHeaderRow;
  final bool isHeaderRow = dataCell.dataRow!.rowType == RowType.headerRow;
  final bool isDataRow = dataCell.dataRow!.rowType == RowType.dataRow;
  final bool isCaptionSummaryCoverdRow =
      dataCell.dataRow!.rowType == RowType.captionSummaryCoveredRow;
  final bool isTableSummaryRow =
      dataCell.dataRow!.rowType == RowType.tableSummaryRow;

  // To skip bottom border for the top data row of the starting row of bottom table
  // summary rows and draw top border for the bottom summary start row instead.
  final bool canSkipBottomBorder = grid_helper.getTableSummaryCount(
              dataGridConfiguration, GridTableSummaryRowPosition.bottom) >
          0 &&
      dataCell.rowIndex ==
          grid_helper.getStartBottomSummaryRowIndex(dataGridConfiguration) - 1;

  // To draw the top border for the starting row of the bottom table summary row.
  final bool canDrawStartBottomSummaryRowTopBorder = isTableSummaryCell &&
      dataCell.rowIndex ==
          grid_helper.getStartBottomSummaryRowIndex(dataGridConfiguration);

  final int groupedColumnsLength =
      dataGridConfiguration.source.groupedColumns.length;

  final bool isGrouping =
      dataGridConfiguration.source.groupedColumns.isNotEmpty;

  final bool canDrawHeaderHorizontalBorder =
      (dataGridConfiguration.headerGridLinesVisibility ==
                  GridLinesVisibility.horizontal ||
              dataGridConfiguration.headerGridLinesVisibility ==
                  GridLinesVisibility.both) &&
          (isHeaderCell ||
              isStackedHeaderCell ||
              (isIndentCell && (isHeaderRow || isStackedHeaderRow)));

  final bool canDrawHeaderVerticalBorder =
      (dataGridConfiguration.headerGridLinesVisibility ==
                  GridLinesVisibility.vertical ||
              dataGridConfiguration.headerGridLinesVisibility ==
                  GridLinesVisibility.both) &&
          (isHeaderCell ||
              isStackedHeaderCell ||
              (isIndentCell && (isHeaderRow || isStackedHeaderRow)));

  final ColumnDragAndDropController dragAndDropController =
      dataGridConfiguration.columnDragAndDropController;

  final bool canDrawLeftColumnDragAndDropIndicator = dataGridConfiguration
          .allowColumnsDragging &&
      dragAndDropController.canDrawRightIndicator != null &&
      !dragAndDropController.canDrawRightIndicator! &&
      dragAndDropController.columnIndex == dataCell.columnIndex &&
      (!dataGridConfiguration.showCheckboxColumn
          ? dragAndDropController.dragColumnStartIndex != dataCell.columnIndex
          : dragAndDropController.dragColumnStartIndex! + 1 !=
              dataCell.columnIndex) &&
      isHeaderCell;

  final bool canDrawRightColumnDragAndDropIndicator = dataGridConfiguration
          .allowColumnsDragging &&
      dragAndDropController.canDrawRightIndicator != null &&
      dragAndDropController.canDrawRightIndicator! &&
      dragAndDropController.columnIndex == dataCell.columnIndex &&
      (!dataGridConfiguration.showCheckboxColumn
          ? dragAndDropController.dragColumnStartIndex != dataCell.columnIndex
          : dragAndDropController.dragColumnStartIndex! + 1 !=
              dataCell.columnIndex) &&
      isHeaderCell;

  final bool canSkipLeftColumnDragAndDropIndicator =
      canDrawLeftColumnDragAndDropIndicator &&
          (!dataGridConfiguration.showCheckboxColumn
              ? dragAndDropController.dragColumnStartIndex! + 1 ==
                  dataCell.columnIndex
              : (dragAndDropController.dragColumnStartIndex! + 2 ==
                      dataCell.columnIndex ||
                  dragAndDropController.columnIndex == 0));

  final bool canSkipRightColumnDragAndDropIndicator =
      canDrawRightColumnDragAndDropIndicator &&
          (!dataGridConfiguration.showCheckboxColumn
              ? dragAndDropController.dragColumnStartIndex! - 1 ==
                  dataCell.columnIndex
              : (dragAndDropController.dragColumnStartIndex! ==
                      dataCell.columnIndex ||
                  dragAndDropController.columnIndex == 0));

  final bool canDrawHorizontalBorder =
      (dataGridConfiguration.gridLinesVisibility ==
                  GridLinesVisibility.horizontal ||
              dataGridConfiguration.gridLinesVisibility ==
                  GridLinesVisibility.both) &&
          !isHeaderCell &&
          !isStackedHeaderCell;

  final bool canDrawVerticalBorder =
      (dataGridConfiguration.gridLinesVisibility ==
                  GridLinesVisibility.vertical ||
              dataGridConfiguration.gridLinesVisibility ==
                  GridLinesVisibility.both) &&
          !isStackedHeaderCell &&
          !isTableSummaryCell &&
          !isHeaderCell;

  final GridColumn firstVisibleColumn = dataGridConfiguration.columns
      .firstWhere((GridColumn column) => column.visible && column.width != 0.0);

  final GridColumn? column = dataCell.gridColumn;

  // To draw the top outer border for the DataGrid.
  final bool canDrawGridTopOuterBorder = rowIndex == 0 &&
      dataGridConfiguration.headerGridLinesVisibility !=
          GridLinesVisibility.none;

  // To draw the left outer border for the indent cell of Headers.
  final bool canDrawHeaderIndentLeftOuterBorder = isGrouping &&
      (isHeaderRow || isStackedHeaderRow) &&
      columnIndex == 0 &&
      dataGridConfiguration.headerGridLinesVisibility !=
          GridLinesVisibility.none;

  // To draw the left outer border for the indent cell of DataGrid rows.
  final bool canDrawIndentLeftOuterBorder = isGrouping &&
      (isDataRow || isCaptionSummaryCoverdRow) &&
      columnIndex == 0 &&
      dataGridConfiguration.gridLinesVisibility != GridLinesVisibility.none;

  // To draw the left outer border for the DataGrid rows with indentColumnWidth as zero.
  final bool canDrawGroupingRowsLeftOuterBoder = isGrouping &&
      dataGridConfiguration.dataGridThemeHelper!.indentColumnWidth == 0 &&
      ((isDataRow && column!.columnName == firstVisibleColumn.columnName) ||
          isCaptionSummaryCoverdRow) &&
      dataGridConfiguration.headerGridLinesVisibility !=
          GridLinesVisibility.none;

  // To draw the left outer border for the Header with indentColumnWidth as zero.
  final bool canDrawGroupingHeaderLeftOuterBoder = isGrouping &&
      dataGridConfiguration.dataGridThemeHelper!.indentColumnWidth == 0 &&
      (isHeaderRow || isStackedHeaderRow) &&
      column!.columnName == firstVisibleColumn.columnName &&
      dataGridConfiguration.gridLinesVisibility != GridLinesVisibility.none;

  // To draw the left outer border for the DataGrid Headers.
  final bool canDrawGridHeaderLeftOuterBorder =
      ((isHeaderCell || isStackedHeaderCell) &&
              dataGridConfiguration.headerGridLinesVisibility !=
                  GridLinesVisibility.none &&
              (column!.columnName == firstVisibleColumn.columnName &&
                  !isGrouping)) ||
          canDrawGroupingHeaderLeftOuterBoder ||
          canDrawHeaderIndentLeftOuterBorder;

  // To draw the left outer border for the DataGrid Rows.
  final bool canDrawGridLeftOuterBorder =
      ((isRowCell || isTableSummaryCell || isCheckboxCell) &&
              dataGridConfiguration.gridLinesVisibility !=
                  GridLinesVisibility.none &&
              (column!.columnName == firstVisibleColumn.columnName &&
                  !isGrouping)) ||
          canDrawGroupingRowsLeftOuterBoder ||
          canDrawIndentLeftOuterBorder;

  // Frozen column and row checking
  final bool canDrawBottomFrozenBorder =
      dataGridConfiguration.frozenRowsCount.isFinite &&
          dataGridConfiguration.frozenRowsCount > 0 &&
          grid_helper.getLastFrozenRowIndex(dataGridConfiguration) == rowIndex;

  final bool canDrawTopFrozenBorder =
      dataGridConfiguration.footerFrozenRowsCount.isFinite &&
          dataGridConfiguration.footerFrozenRowsCount > 0 &&
          grid_helper.getStartFooterFrozenRowIndex(dataGridConfiguration) ==
              rowIndex;

  final bool canDrawRightFrozenBorder =
      dataGridConfiguration.frozenColumnsCount.isFinite &&
          dataGridConfiguration.frozenColumnsCount > 0 &&
          grid_helper.getLastFrozenColumnIndex(dataGridConfiguration) ==
              columnIndex;

  final bool canDrawLeftFrozenBorder =
      dataGridConfiguration.footerFrozenColumnsCount.isFinite &&
          dataGridConfiguration.footerFrozenColumnsCount > 0 &&
          grid_helper.getStartFooterFrozenColumnIndex(dataGridConfiguration) ==
              columnIndex;

  final bool isFrozenPaneElevationApplied =
      dataGridConfiguration.dataGridThemeHelper!.frozenPaneElevation! > 0.0;

  final Color frozenPaneLineColor =
      dataGridConfiguration.dataGridThemeHelper!.frozenPaneLineColor!;

  final double frozenPaneLineWidth =
      dataGridConfiguration.dataGridThemeHelper!.frozenPaneLineWidth!;

  final bool canDrawIndentRightBorder = canDrawVerticalBorder &&
      (dataGridConfiguration.source.groupedColumns.isNotEmpty &&
              (columnIndex >= 0 &&
                  columnIndex < groupedColumnsLength &&
                  isIndentCell &&
                  columnIndex < dataCell.dataRow!.rowLevel - 1) ||
          (isDataRow && isIndentCell && columnIndex < groupedColumnsLength));
  final Object? rowData = dataCell.dataRow!.rowData;

  final bool canDrawTableSummaryRowIndentBorder =
      (dataGridConfiguration.gridLinesVisibility ==
                  GridLinesVisibility.horizontal ||
              dataGridConfiguration.gridLinesVisibility ==
                  GridLinesVisibility.both) &&
          (isIndentCell && isTableSummaryRow);

  BorderSide getLeftBorder() {
    if ((columnIndex == 0 &&
            (canDrawVerticalBorder ||
                canDrawHeaderVerticalBorder ||
                canDrawLeftColumnDragAndDropIndicator)) ||
        canDrawLeftFrozenBorder ||
        canDrawGridHeaderLeftOuterBorder ||
        canDrawGridLeftOuterBorder) {
      if (canDrawLeftColumnDragAndDropIndicator &&
          !canSkipLeftColumnDragAndDropIndicator) {
        return BorderSide(
            width: dataGridConfiguration
                .dataGridThemeHelper!.columnDragIndicatorStrokeWidth!,
            color: dataGridConfiguration
                .dataGridThemeHelper!.columnDragIndicatorColor!);
      }
      if (canDrawLeftFrozenBorder &&
          !isStackedHeaderCell &&
          !isFrozenPaneElevationApplied) {
        return BorderSide(
            width: frozenPaneLineWidth, color: frozenPaneLineColor);
      } else if ((columnIndex > 0 &&
              ((canDrawVerticalBorder || canDrawHeaderVerticalBorder) &&
                  !canDrawLeftFrozenBorder)) ||
          (canDrawGridLeftOuterBorder || canDrawGridHeaderLeftOuterBorder)) {
        return BorderSide(width: borderWidth, color: borderColor);
      } else {
        return BorderSide.none;
      }
    } else if (canDrawLeftColumnDragAndDropIndicator &&
        !canSkipLeftColumnDragAndDropIndicator) {
      return BorderSide(
          width: dataGridConfiguration
              .dataGridThemeHelper!.columnDragIndicatorStrokeWidth!,
          color: dataGridConfiguration
              .dataGridThemeHelper!.columnDragIndicatorColor!);
    } else {
      return BorderSide.none;
    }
  }

  BorderSide getTopBorder() {
    if (isSelected &&
        (dataGridConfiguration.dataGridThemeHelper!.gridSelectedRowLineStrokeWidth!=null || dataGridConfiguration.dataGridThemeHelper!.gridSelectedRowLineColor!=null)
    ) {
      return BorderSide(width: borderWidth, color: borderColor);
    }
    if ((rowIndex == 0 && (canDrawHorizontalBorder || canDrawHeaderHorizontalBorder)) ||
        canDrawTopFrozenBorder ||
        canDrawStartBottomSummaryRowTopBorder ||
        canDrawGridTopOuterBorder) {
      if (canDrawTopFrozenBorder &&
          !isStackedHeaderCell &&
          !isFrozenPaneElevationApplied) {
        return BorderSide(
            width: frozenPaneLineWidth, color: frozenPaneLineColor);
      } else if ((canDrawHorizontalBorder &&
              canDrawStartBottomSummaryRowTopBorder) ||
          canDrawGridTopOuterBorder) {
        return BorderSide(width: borderWidth, color: borderColor);
      } else {
        return BorderSide.none;
      }
    } else {
      return BorderSide.none;
    }
  }

  BorderSide getRightBorder() {
    if (canDrawVerticalBorder ||
        canDrawHeaderVerticalBorder ||
        canDrawRightFrozenBorder ||
        canDrawRightColumnDragAndDropIndicator ||
        canDrawIndentRightBorder) {
      if (canDrawRightFrozenBorder &&
          !isStackedHeaderCell &&
          !isFrozenPaneElevationApplied) {
        return BorderSide(
            width: frozenPaneLineWidth, color: frozenPaneLineColor);
      } else if (canDrawRightColumnDragAndDropIndicator &&
          !canSkipRightColumnDragAndDropIndicator) {
        return BorderSide(
            width: dataGridConfiguration
                .dataGridThemeHelper!.columnDragIndicatorStrokeWidth!,
            color: dataGridConfiguration
                .dataGridThemeHelper!.columnDragIndicatorColor!);
      } else if ((canDrawVerticalBorder || canDrawHeaderVerticalBorder) &&
          !canDrawRightFrozenBorder &&
          !isCaptionSummaryCell &&
          !isIndentCell) {
        return BorderSide(width: borderWidth, color: borderColor);
      } else if ((canDrawIndentRightBorder ||
              canDrawHeaderVerticalBorder ||
              isCaptionSummaryCell) &&
          !canDrawRightFrozenBorder) {
        return BorderSide(width: borderWidth, color: borderColor);
      } else {
        return BorderSide.none;
      }
    } else {
      return BorderSide.none;
    }
  }

  BorderSide getBottomBorder() {
    if (canDrawHorizontalBorder ||
        canDrawHeaderHorizontalBorder ||
        canDrawBottomFrozenBorder) {
      if (canDrawBottomFrozenBorder &&
          !isStackedHeaderCell &&
          !isFrozenPaneElevationApplied) {
        return BorderSide(
            width: frozenPaneLineWidth, color: frozenPaneLineColor);
      } else if (!canDrawBottomFrozenBorder &&
          !canSkipBottomBorder &&
          !isIndentCell) {
        return BorderSide(width: borderWidth, color: borderColor);
      } else if (isGrouping) {
        if (canDrawHeaderHorizontalBorder ||
            canDrawTableSummaryRowIndentBorder) {
          return BorderSide(width: borderWidth, color: borderColor);
        }
        final dynamic group = getNextGroupInfo(rowData, dataGridConfiguration);
        if (group is Group &&
            isIndentCell &&
            columnIndex >= group.level - 1 &&
            rowIndex >= dataGridConfiguration.headerLineCount) {
          return BorderSide(width: borderWidth, color: borderColor);
        } else {
          return BorderSide.none;
        }
      } else {
        return BorderSide.none;
      }
    } else {
      return BorderSide.none;
    }
  }

  return BorderDirectional(
    start: getLeftBorder(),
    top: getTopBorder(),
    end: getRightBorder(),
    bottom: getBottomBorder(),
  );
}

// ez a header-t is és a data cellát is rajzolja! - tvg
Widget _wrapInsideCellContainer(
    {required DataGridConfiguration dataGridConfiguration,
    required DataCellBase dataCell,
    required Key key,
    required Color backgroundColor,
    required Widget child}) {
  final Color color =
      dataGridConfiguration.dataGridThemeHelper!.currentCellStyle!.borderColor;
  final double borderWidth =
      dataGridConfiguration.dataGridThemeHelper!.currentCellStyle!.borderWidth;

  Border getBorder() {
    final bool isCurrentCell = dataCell.isCurrentCell;
    return Border(
      bottom: isCurrentCell
          ? BorderSide(color: color, width: borderWidth)
          : BorderSide.none,
      left: isCurrentCell
          ? BorderSide(color: color, width: borderWidth)
          : BorderSide.none,
      top: isCurrentCell
          ? BorderSide(color: color, width: borderWidth)
          : BorderSide.none,
      right: isCurrentCell
          ? BorderSide(color: color, width: borderWidth)
          : BorderSide.none,
    );
  }

  double getCellHeight(DataCellBase dataCell, double defaultHeight) {
    // Restricts the height calculation to the invisible data cell.
    if (!dataCell.isVisible) {
      return 0.0;
    }

    double height;
    if (dataCell.rowSpan > 0) {
      height = dataCell.dataRow!.getRowHeight(
          dataCell.rowIndex - dataCell.rowSpan, dataCell.rowIndex);
    } else {
      height = defaultHeight;
    }
    return height;
  }

  double getCellWidth(DataCellBase dataCell, double defaultWidth) {
    // Restricts the width calculation to the invisible data cell.
    if (!dataCell.isVisible) {
      return 0.0;
    }

    double width;
    if (dataCell.columnSpan > 0) {
      width = dataCell.dataRow!.getColumnWidth(
          dataCell.columnIndex, dataCell.columnIndex + dataCell.columnSpan);
      if (dataGridConfiguration.source.groupedColumns.isNotEmpty &&
          dataCell.dataRow!.rowType == RowType.tableSummaryCoveredRow) {
        width += dataGridConfiguration.dataGridThemeHelper!.indentColumnWidth *
            dataGridConfiguration.source.groupedColumns.length;
      }
    } else {
      width = defaultWidth;
    }
    return width;
  }

  Widget getChild(BoxConstraints constraint) {
    final double width = getCellWidth(dataCell, constraint.maxWidth);
    final double height = getCellHeight(dataCell, constraint.maxHeight);

    if (dataCell.isCurrentCell &&
        dataCell.cellType != CellType.indentCell &&
        dataCell.cellType != CellType.checkboxCell &&
        dataCell.dataRow!.dataGridRow != null) {
      return Stack(
        children: <Widget>[
          Container(
            width: width,
            height: height,
            color: dataGridConfiguration.dataGridThemeHelper!.currentCellStyle!.backgroundColor,
            child: child,
          ),
          Positioned(
              left: 0,
              top: 0,
              width: width,
              height: height,
              child: IgnorePointer(
                child: Container(
                  key: key,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    border: getBorder(),
                  ),
                ),
              )),
        ],
      );
    } else {
      // ez itt minden cellát kirajzol (header és érték is!) - gabor 2024.09.23 - tvg
      // de a cella hátterét valahogy mégsem - gabor 2024.09.23
      return Container(
        //margin: EdgeInsets.all(0), // TVG - ez működik amúgy - gabor 2024.09.23

        // decoration: BoxDecoration(
        // color: dataCell.isCurrentCell ? Colors.brown.shade200 : Colors.red /* (Colors.brown)*/, // TVG - ez a "dataCell.isCurrentCell" sajnos nem működik  - gabor 2024.09.23
        //   border: Border.all(color: Colors.pink, width: 0, style: BorderStyle.none),
        // ),
        color: backgroundColor,
        // color: Colors.yellow,
        width: width,
        height: height,
        child: child,
      );
    }
  }

  return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraint) {
    return getChild(constraint);
  });
}

bool _invokeGroupChangingCallback(
    DataGridConfiguration dataGridConfiguration, Group group) {
  final DataGridGroupChangingDetails details = DataGridGroupChangingDetails(
      key: group.key, groupLevel: group.level, isExpanded: group.isExpanded);
  if (group.isExpanded) {
    if (dataGridConfiguration.groupCollapsing != null) {
      return dataGridConfiguration.groupCollapsing!(details);
    }
    return true;
  } else {
    if (dataGridConfiguration.groupExpanding != null) {
      return dataGridConfiguration.groupExpanding!(details);
    }
    return true;
  }
}

void _invokeGroupChangedCallback(
    DataGridConfiguration dataGridConfiguration, Group group, bool isExpanded) {
  final DataGridGroupChangedDetails details = DataGridGroupChangedDetails(
      key: group.key, groupLevel: group.level, isExpanded: isExpanded);
  if (dataGridConfiguration.groupCollapsed != null && !isExpanded) {
    dataGridConfiguration.groupCollapsed!(details);
  } else if (dataGridConfiguration.groupExpanded != null && isExpanded) {
    dataGridConfiguration.groupExpanded!(details);
  }
}

// Gesture Events

Future<void> _handleOnTapUp(
    {required TapUpDetails? tapUpDetails,
    required TapDownDetails? tapDownDetails,
    required DataCellBase dataCell,
    required DataGridConfiguration dataGridConfiguration,
    required PointerDeviceKind kind,
    bool isSecondaryTapDown = false}) async {
  // End edit the current editing cell if its editing mode is differed
  if (dataGridConfiguration.currentCell.isEditing) {
    if (await dataGridConfiguration.currentCell
        .canSubmitCell(dataGridConfiguration)) {
      await dataGridConfiguration.currentCell
          .onCellSubmit(dataGridConfiguration, cancelCanSubmitCell: true);
    } else {
      return;
    }
  }

  if (!isSecondaryTapDown && dataGridConfiguration.onCellTap != null) {
    // Issue:
    // FLUT-865739-A null exception occurred when expanding the group alongside the onCellTap callback.
    //
    // Reason for the issue: The gridcolumn is null when the tapping the caption summary cell.
    //
    // Fix: We need to check the gridcolumn is null or not before invoking the onCellDoubleTap callback.
    // For the caption summary cell, we need to get the first visible column from the columns collection.
    final GridColumn? column =
        grid_helper.getGridColumn(dataGridConfiguration, dataCell);

    if (column == null) {
      return;
    }

    final DataGridCellTapDetails details = DataGridCellTapDetails(
        rowColumnIndex: RowColumnIndex(dataCell.rowIndex, dataCell.columnIndex),
        column: column,
        globalPosition: tapDownDetails != null
            ? tapDownDetails.globalPosition
            : tapUpDetails!.globalPosition,
        localPosition: tapDownDetails != null
            ? tapDownDetails.localPosition
            : tapUpDetails!.localPosition,
        kind: kind);
    dataGridConfiguration.onCellTap!(details);
  }

  dataGridConfiguration.dataGridFocusNode?.requestFocus();
  dataCell.onTouchUp();

  // Expand or collpase the individual group by tap.
  if (dataGridConfiguration.source.groupedColumns.isNotEmpty &&
      dataGridConfiguration.allowExpandCollapseGroup &&
      dataCell.dataRow!.rowType == RowType.captionSummaryCoveredRow) {
    final int rowIndex = resolveStartRecordIndex(
        dataGridConfiguration, dataCell.dataRow!.rowIndex);
    if (rowIndex >= 0) {
      final Group group = getGroupElement(dataGridConfiguration, rowIndex);
      if (group.isExpanded) {
        if (_invokeGroupChangingCallback(dataGridConfiguration, group)) {
          dataGridConfiguration.group!
              .collapseGroups(group, dataGridConfiguration.group, rowIndex);
          dataGridConfiguration.groupExpandCollapseRowIndex =
              dataCell.dataRow!.rowIndex;
          notifyDataGridPropertyChangeListeners(dataGridConfiguration.source,
              propertyName: 'grouping');
          _invokeGroupChangedCallback(dataGridConfiguration, group, false);
        }
      } else {
        if (_invokeGroupChangingCallback(dataGridConfiguration, group)) {
          dataGridConfiguration.group!
              .expandGroups(group, dataGridConfiguration.group, rowIndex);
          dataGridConfiguration.groupExpandCollapseRowIndex =
              dataCell.dataRow!.rowIndex;
          notifyDataGridPropertyChangeListeners(dataGridConfiguration.source,
              propertyName: 'grouping');
          _invokeGroupChangedCallback(dataGridConfiguration, group, true);
        }
      }
    }
  }

  // Init the editing based on the editing mode
  if (dataGridConfiguration.editingGestureType == EditingGestureType.tap) {
    dataGridConfiguration.currentCell
        .onCellBeginEdit(editingDataCell: dataCell);
  }
}

Future<void> _handleOnDoubleTap(
    {required DataCellBase dataCell,
    required DataGridConfiguration dataGridConfiguration}) async {
  // End edit the current editing cell if its editing mode is differed
  if (dataGridConfiguration.currentCell.isEditing) {
    if (await dataGridConfiguration.currentCell
        .canSubmitCell(dataGridConfiguration)) {
      await dataGridConfiguration.currentCell
          .onCellSubmit(dataGridConfiguration, cancelCanSubmitCell: true);
    } else {
      return;
    }
  }

  if (dataGridConfiguration.onCellDoubleTap != null) {
    final GridColumn? column =
        grid_helper.getGridColumn(dataGridConfiguration, dataCell);

    if (column == null) {
      return;
    }

    final DataGridCellDoubleTapDetails details = DataGridCellDoubleTapDetails(
        rowColumnIndex: RowColumnIndex(dataCell.rowIndex, dataCell.columnIndex),
        column: column);
    dataGridConfiguration.onCellDoubleTap!(details);
  }

  dataGridConfiguration.dataGridFocusNode?.requestFocus();
  dataCell.onTouchUp();

  // Init the editing based on the editing mode
  if (dataGridConfiguration.editingGestureType ==
      EditingGestureType.doubleTap) {
    dataGridConfiguration.currentCell
        .onCellBeginEdit(editingDataCell: dataCell);
  }
}

Future<void> _handleOnSecondaryTapUp(
    {required TapUpDetails tapUpDetails,
    required DataCellBase dataCell,
    required DataGridConfiguration dataGridConfiguration,
    required PointerDeviceKind kind}) async {
  // Need to end the editing cell when interacting with other tap gesture
  if (dataGridConfiguration.currentCell.isEditing) {
    if (await dataGridConfiguration.currentCell
        .canSubmitCell(dataGridConfiguration)) {
      await dataGridConfiguration.currentCell
          .onCellSubmit(dataGridConfiguration, cancelCanSubmitCell: true);
    } else {
      return;
    }
  }

  if (dataGridConfiguration.onCellSecondaryTap != null) {
    final GridColumn? column =
        grid_helper.getGridColumn(dataGridConfiguration, dataCell);

    if (column == null) {
      return;
    }

    final DataGridCellTapDetails details = DataGridCellTapDetails(
        rowColumnIndex: RowColumnIndex(dataCell.rowIndex, dataCell.columnIndex),
        column: column,
        globalPosition: tapUpDetails.globalPosition,
        localPosition: tapUpDetails.localPosition,
        kind: kind);
    dataGridConfiguration.onCellSecondaryTap!(details);
  }
}
