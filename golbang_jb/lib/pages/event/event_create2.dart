import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golbang/pages/event/widgets/group_card.dart';
import 'package:golbang/pages/event/widgets/no_api_participant_dialog.dart';
import 'package:golbang/pages/event/widgets/toggle_bottons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/club.dart';
import '../../models/create_event.dart';
import '../../models/create_participant.dart';
import '../../models/enum/event.dart';
import '../../models/profile/member_profile.dart';
import '../../repoisitory/secure_storage.dart';
import '../../services/event_service.dart';

class EventsCreate2 extends ConsumerStatefulWidget {
  final String title;
  final Club? selectedClub;
  final LatLng? selectedLocation;
  final DateTime startDate;
  final DateTime endDate;
  final List<ClubMemberProfile> selectedParticipants;
  final GameMode selectedGameMode;

  EventsCreate2({
    required this.title,
    required this.selectedClub,
    required this.selectedLocation,
    required this.startDate,
    required this.endDate,
    required this.selectedParticipants,
    required this.selectedGameMode,
  });

  @override
  _EventsCreate2State createState() => _EventsCreate2State();
}

class _EventsCreate2State extends ConsumerState<EventsCreate2> {
  GameMode gameMode = GameMode.STROKE;
  TeamConfig teamConfig = TeamConfig.NONE;
  String groupSetting = '직접 설정';
  String numberOfGroups = '8개';
  String numberOfPlayers = '4명';
  bool isAutoMatching = false;
  bool isTeam = false;
  List<Map<String, List<CreateParticipant>>> groups = [];
  List<CreateParticipant> _selectedParticipants = [];
  bool hasDuplicateParticipants = false;
  bool areGroupsEmpty = true;
  bool allParticipantsAssigned = false;
  late EventService _eventService;

  @override
  void initState() {
    super.initState();
    _eventService = EventService(ref.read(secureStorageProvider));
    _initializeParticipants();
  }

  void _initializeParticipants() {
    _selectedParticipants = widget.selectedParticipants.map((participant) {
      return CreateParticipant(
        memberId: participant.memberId,
        name: participant.name,
        profileImage: participant.profileImage,
        teamType: teamConfig,
        groupType: groupSetting,
      );
    }).toList();
  }

  void _createGroups() {
    int numGroups = int.parse(numberOfGroups.replaceAll('개', ''));
    setState(() {
      groups = List.generate(
        numGroups,
            (index) => {
          '조${index + 1}': [],
        },
      );
      _validateForm();
    });
  }

  bool _checkForDuplicateParticipants() {
    final allParticipants = <int>{};
    for (var group in groups) {
      for (var participant in group.values.first) {
        if (!allParticipants.add(participant.memberId)) {
          print('참가자 중복입니다.true');
          return true;
        }
      }
    }
    print('참가자 중복이 아닙니다.false');
    return false;
  }

  bool _checkIfAllParticipantsAssigned() {
    final assignedParticipants = <int>{};
    for (var group in groups) {
      for (var participant in group.values.first) {
        assignedParticipants.add(participant.memberId);
      }
    }
    print('참가자 할당여부 ${assignedParticipants.length == _selectedParticipants.length}');
    return assignedParticipants.length == _selectedParticipants.length;
  }

  void _validateForm() {
    setState(() {
      hasDuplicateParticipants = _checkForDuplicateParticipants();
      allParticipantsAssigned = _checkIfAllParticipantsAssigned();
      print("---------------------------------------------------");
    });
  }

  void _showParticipantSelectionDialog(String groupName) {
    List<CreateParticipant> groupParticipants =
    groups.firstWhere((group) => group.keys.first == groupName)[groupName]!;

    showDialog(
      context: context,
      builder: (context) {
        return ParticipantSelectionDialog(
          groupName: groupName,
          participants: _selectedParticipants,
          selectedParticipants: groupParticipants,
          onSelectionComplete: (List<CreateParticipant> updatedParticipants) {
            setState(() {
              groups
                  .firstWhere((group) => group.keys.first == groupName)[groupName] =
                  updatedParticipants;
              _validateForm();
            });
          },
        );
      },
    );
  }

  Future<void> _onCompletePressed() async {
    // 이벤트 데이터 생성
    final event = CreateEvent(
      eventId: 0, // 이벤트 ID는 새로 생성 시 0 또는 null로 설정
      eventTitle: widget.title,
      location: widget.selectedLocation?.toString() ?? "Unknown Location",
      startDateTime: widget.startDate,
      endDateTime: widget.endDate,
      repeatType: "NONE",
      gameMode: gameMode.value,
      alertDateTime: "", //TODO: 임시 조치
    );

    // API 호출
    bool success = await _eventService.postEvent(
        clubId: widget.selectedClub!.id,
        event: event,
        participants: _selectedParticipants);

    // 결과에 따라 처리
    if (success) {
      Navigator.of(context).pop(); // 성공 시 페이지 닫기
      Navigator.of(context).pop(); // 성공 시 페이지 닫기
      // Navigator.popUntil(context, ModalRoute.withName('/eventMain'));
    } else {
      // 실패 시 기본 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이벤트 생성에 실패했습니다. 나중에 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text('이벤트 생성'),
        actions: [
          TextButton(
            onPressed: (hasDuplicateParticipants || !allParticipantsAssigned)
                ? null
                : _onCompletePressed,
            child: Text(
              '완료',
              style: TextStyle(
                color: (hasDuplicateParticipants || !allParticipantsAssigned)
                    ? Colors.grey
                    : Colors.teal,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<GameMode>(
              decoration: InputDecoration(
                labelText: '게임모드',
                border: OutlineInputBorder(),
              ),
              value: gameMode,
              onChanged: null,
              items: GameMode.values.map((mode) {
                return DropdownMenuItem<GameMode>(
                  value: mode,
                  child: Text(
                    mode == GameMode.STROKE ? '스트로크' : mode.toString(),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            ToggleButtonsWidget(
              onSelectedMatchingType: (int index) {
                setState(() {
                  isAutoMatching = index == 0;
                });
              },
              onSelectedTeamType: (int index) {
                setState(() {
                  isTeam = index == 1;
                });
              },
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: '직접 설정',
                border: OutlineInputBorder(),
              ),
              value: groupSetting,
              onChanged: (newValue) {
                setState(() {
                  groupSetting = newValue!;
                });
              },
              items: ['직접 설정'].map((setting) {
                return DropdownMenuItem<String>(
                  value: setting,
                  child: Text(setting),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: '팀 수',
                      border: OutlineInputBorder(),
                    ),
                    value: numberOfGroups,
                    onChanged: (newValue) {
                      setState(() {
                        numberOfGroups = newValue!;
                      });
                    },
                    items: ['8개', '7개', '6개', '5개', '4개', '3개', '2개', '1개'].map((number) {
                      return DropdownMenuItem<String>(
                        value: number,
                        child: Text(number),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: '인원 수',
                      border: OutlineInputBorder(),
                    ),
                    value: numberOfPlayers,
                    onChanged: (newValue) {
                      setState(() {
                        numberOfPlayers = newValue!;
                      });
                    },
                    items: ['4명', '3명', '2명'].map((number) {
                      return DropdownMenuItem<String>(
                        value: number,
                        child: Text(number),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createGroups,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('조 생성'),
            ),
            if (groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('추가 버튼을 눌러 멤버를 추가해보세요'),
                    SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start, // 상단 정렬 설정
                        children: groups.map((group) {
                          String groupName = group.keys.first;
                          List<CreateParticipant> members = group[groupName]!;

                          return GroupCard(
                            groupName: groupName,
                            members: members,
                            onAddParticipant: () {
                              _showParticipantSelectionDialog(groupName);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}