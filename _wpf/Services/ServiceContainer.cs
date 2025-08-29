using System;
using System.Collections.Generic;
using PraxisWpf.Interfaces;

namespace PraxisWpf.Services
{
    public static class ServiceContainer
    {
        private static readonly Dictionary<Type, object> _services = new();

        public static void Register<TInterface>(TInterface implementation) where TInterface : class
        {
            var serviceType = typeof(TInterface);
            _services[serviceType] = implementation;
            Logger.Debug("ServiceContainer", $"Registered service: {serviceType.Name}");
        }

        public static TInterface Get<TInterface>() where TInterface : class
        {
            var serviceType = typeof(TInterface);
            if (_services.TryGetValue(serviceType, out var service))
            {
                return (TInterface)service;
            }
            throw new InvalidOperationException($"Service of type {serviceType.Name} not registered");
        }

        // Legacy methods for backward compatibility
        public static void RegisterDataService(IDataService dataService)
        {
            Register<IDataService>(dataService);
        }

        public static IDataService GetDataService()
        {
            return Get<IDataService>();
        }

        public static void RegisterDialogService(IDialogService dialogService)
        {
            Register<IDialogService>(dialogService);
        }

        public static IDialogService GetDialogService()
        {
            return Get<IDialogService>();
        }

        public static void Clear()
        {
            _services.Clear();
            Logger.Debug("ServiceContainer", "All services cleared");
        }
    }
}