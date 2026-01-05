import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/cell_data.dart';
import '../../models/compare_mode.dart';
import '../../models/diff_marker.dart';
import '../../utils/color_utils.dart';
import '../../widgets/calculation_panel.dart';
import '../../widgets/number_cell.dart';
import '../../widgets/number_grid.dart';
import 'game_logic.dart';
import 'game_models.dart';
import 'game_storage.dart';
import 'widgets/config_panel.dart';
import 'widgets/edit_cell_dialog.dart';
part 'dye_game_page_state.dart';

class DyeGamePage extends StatefulWidget {
  const DyeGamePage({super.key});

  @override
  State<DyeGamePage> createState() => _DyeGamePageState();
}
