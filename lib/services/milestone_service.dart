import '../models/milestone_model.dart';
import 'dart:async';
import '../providers/game_state.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MilestoneService {
  // 1. GET THE LIST
  List<Milestone> getHardcodedMilestones() {
    return [
      Milestone(id: 'junk_test', title: 'First Leaderboard Loader', description: 'First pioneer to access the Hub.', icon: Icons.bug_report, winnerName: 'Scrimshaw & Sons', wonAt: DateTime.now()),
      Milestone(id: 'rename_company', title: 'Corporate Identity', description: 'First company to rename themselves', icon: Icons.badge),
      Milestone(id: 'solars_10m', title: 'Deca-Millionaire', description: 'First company to be worth 10 million solars', icon: Icons.monetization_on),
      Milestone(id: 'solars_50m', title: 'Centurion Club', description: 'First company to be worth 50 million solars', icon: Icons.account_balance),
      Milestone(id: 'contracts_1000', title: 'Logistics Legend', description: 'First company to complete 1000 shipping contracts', icon: Icons.local_shipping),
      Milestone(id: 'tier5_mule', title: 'Heavy Hauler Expert', description: 'First company to have a Tier 5 Mule', icon: Icons.anchor),
      Milestone(id: 'tier5_sprinter', title: 'Void Racer', description: 'First company to have a Tier 5 Sprinter', icon: Icons.bolt),
      Milestone(id: 'tier5_miner', title: 'Core Stripper', description: 'First company to have a Tier 5 Miner', icon: Icons.precision_manufacturing),
      Milestone(id: 'tier5_tanker', title: 'Gas Giant', description: 'First company to have a Tier 5 Tanker', icon: Icons.ev_station),
      Milestone(id: 'tier5_harvester', title: 'Rift Walker', description: 'First company to have a Tier 5 Harvester', icon: Icons.auto_awesome),
      Milestone(id: 'all_tier5', title: 'Fleet Master', description: 'First company to have a Tier 5 ship of every class', icon: Icons.groups),
      Milestone(id: 'dist_30au', title: 'Long Haul Hero', description: 'First company to complete a contract of over 30 AU', icon: Icons.explore),
      Milestone(id: 'ore_5000', title: 'Mineral Mogul', description: 'First company to mine 5000 m3 of Ore', icon: Icons.layers),
      Milestone(id: 'gas_5000', title: 'Atmospheric Tycoon', description: 'First company to bring in 5000 m3 of Gas', icon: Icons.air),
      Milestone(id: 'crystals_5000', title: 'Resonance King', description: 'First company to harvest 5000 m3 of Crystals', icon: Icons.diamond),
      Milestone(id: 'max_base', title: 'Command Center', description: 'First company to Max out base upgrades', icon: Icons.castle),
    ];
  }

  Timer? _debounceTimer;

  void requestCheck(GameState state) {
    // If a check was already scheduled, cancel it and restart the 5-second clock
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(seconds: 5), () {
      checkForNewClaims(state);
      debugPrint("📢 DEBOUNCED MILESTONE CHECK EXECUTED");
    });
  }

// We'll use this to keep track of what still needs checking locally
  Set<String> _unclaimedIds = {};

  void checkForNewClaims(GameState state) {
    if (_unclaimedIds.isEmpty) {
      debugPrint("MilestoneService: No active milestones to check.");
      return;
    }
    for (String id in List.from(_unclaimedIds)) {
      bool met = false;

      switch (id) {
        case 'rename_company':
          if (state.hasNamedCompany && state.companyName != "Establishing Link...") {
            met = true;
          }
          break;

        case 'solars_10m':
          if (state.netWorth >= 10000000) met = true;
          break;

        case 'solars_50m':
          if (state.netWorth >= 50000000) met = true;
          break;

        case 'contracts_1000':
          if (state.totalContracts >= 1000) met = true;
          break;

        case 'ore_50000':
          if (state.totalOreHarvested >= 50000) met = true;
          break;

        case 'gas_50000':
          if (state.totalGasHarvested >= 50000) met = true;
          break;

        case 'crystals_50000':
          if (state.totalCrystalsHarvested >= 50000) met = true;
          break;

        case 'dist_30au':
          // This looks at your missionLogs for any entry where the distance was >= 30
          final longHaul = state.missionLogs.any((mission) => mission.distance >= 30);
          if (longHaul) met = true;
          break;

        case 'max_base':
          if (state.hangarLevel >= 5 &&
              state.relayLevel >= 4 && // Based on your logs, Relay is capped at 4
              state.serverFarmLevel >= 5 &&
              state.tradeDepotLevel >= 5 &&
              state.repairGantryLevel >= 5 &&
              state.broadcastingArrayLevel >= 5) {
            met = true;
          }
          break;
      }

      if (met) {
        _claimMilestone(id, state.companyName);
        _unclaimedIds.remove(id);
      }
    }
  }

  Future<void> _claimMilestone(String id, String companyName) async {
    final docRef = FirebaseFirestore.instance.collection('milestones').doc(id);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);

        // Check if it's ALREADY claimed on the server before we write
        if (snapshot.exists && snapshot.get('winnerName') == null) {
          transaction.update(docRef, {
            'winnerName': companyName,
            'wonAt': FieldValue.serverTimestamp(), // Official Galactic Time
          });
          debugPrint("🏆 SUCCESS: $companyName claimed $id!");
        } else {
          debugPrint("🚫 LATE: $id was already snatched by someone else.");
        }
      });
    } catch (e) {
      debugPrint("❌ CLAIM ERROR: $e");
    }
  }

  // lib/services/milestone_service.dart

  void initializeGlobalListener() {
    FirebaseFirestore.instance.collection('milestones').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>;
        final String id = change.doc.id;
        final String? winner = data['winnerName'];

        if (winner == null || winner.isEmpty) {
          _unclaimedIds.add(id);
          debugPrint("🛰️ REGISTRY: Milestone '$id' is currently UNCLAIMED.");
        } else {
          // If it was in our local set but now has a winner, someone just won!
          if (_unclaimedIds.contains(id)) {
            _unclaimedIds.remove(id);
            debugPrint("🏆 REGISTRY: NEW CLAIM! '$id' won by $winner.");
          } else {
            // It's already claimed and we already knew it (it wasn't in our set)
            debugPrint("📋 REGISTRY: '$id' is already occupied by $winner.");
          }
        }
      }
    });
  }

}