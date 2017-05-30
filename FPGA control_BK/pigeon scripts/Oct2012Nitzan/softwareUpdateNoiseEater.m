function softwareUpdateNoiseEater
dic=Dictator.me;

dic.setNovatech('DoublePass','freq',dic.F674,'amp',1000);

Single_Pulse([Pulse('674DDS1Switch',0,15,'freq',dic.SinglePass674freq,'amp',100),...
    Pulse('NoiseEater674',2,10),Pulse('674DoublePass',0,15),...
    Pulse('Repump1033',15,dic.T1033),...
    Pulse('OpticalPumping',16+dic.T1033,dic.Toptpump)])

end